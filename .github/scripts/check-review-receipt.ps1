<#
.SYNOPSIS
    Review-receipt gate: a PR must carry a BCQuality review report with zero blockers.

.DESCRIPTION
    The review itself runs locally, by the author's own agent. This gate never runs
    an LLM. It only checks the receipt the agent left behind:

      1. At least one review report under workshop/reviews/ is added or changed.
      2. Every changed report has the contract frontmatter (see AGENTS.md).
      3. No report has open blockers (blockers > 0) or outcome: failed.
         outcome: partial warns. "Open" = no accept/reject verdict, see AGENTS.md.
      4. Optional (-RestrictPaths): the PR only touches custom/knowledge/** and
         workshop/reviews/**.
      5. Any custom/knowledge/**/*.md in the PR has the six READ frontmatter fields
         and no fenced code blocks, so BCQuality will not silently skip it.

    Works on GitHub Actions, Azure DevOps and locally. Exit code 0 = pass, 1 = fail.

.PARAMETER BaseRef
    Commit or ref to diff against (the PR target). Ignored when -Files is given.

.PARAMETER Files
    Explicit list of changed repo-relative paths. Useful for local testing.

.PARAMETER RestrictPaths
    Fail when the PR touches anything outside custom/knowledge/ and workshop/reviews/.

.PARAMETER ReportFolder
    Where review reports live. Default: workshop/reviews

.EXAMPLE
    pwsh workshop/pipelines/gate/check-review-receipt.ps1 -BaseRef origin/main -RestrictPaths
#>
[CmdletBinding()]
param(
    [string] $BaseRef = 'origin/main',
    [string[]] $Files,
    [switch] $RestrictPaths,
    [string] $ReportFolder = 'workshop/reviews'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:Errors = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()

function Add-GateError([string] $Message, [string] $File) {
    $script:Errors.Add($(if ($File) { "${File}: $Message" } else { $Message }))
    if ($env:TF_BUILD) { Write-Host "##vso[task.logissue type=error$(if ($File) { ";sourcepath=$File" })]$Message" }
    elseif ($env:GITHUB_ACTIONS) { Write-Host "::error$(if ($File) { " file=$File" })::$Message" }
}

function Add-GateWarning([string] $Message, [string] $File) {
    $script:Warnings.Add($(if ($File) { "${File}: $Message" } else { $Message }))
    if ($env:TF_BUILD) { Write-Host "##vso[task.logissue type=warning$(if ($File) { ";sourcepath=$File" })]$Message" }
    elseif ($env:GITHUB_ACTIONS) { Write-Host "::warning$(if ($File) { " file=$File" })::$Message" }
}

# Minimal frontmatter reader: flat "key: value" pairs, enough for the report and
# READ contracts. Returns $null when the file has no frontmatter block.
function Read-Frontmatter([string] $Path) {
    $lines = @(Get-Content -LiteralPath $Path -Encoding utf8)
    if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') { return $null }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { return $null }

    $fm = [ordered]@{}
    $lastKey = $null
    $fmLines = if ($end -gt 1) { $lines[1..($end - 1)] } else { @() }
    foreach ($line in $fmLines) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^([A-Za-z0-9_-]+)\s*:\s*(.*?)\s*(#.*)?$') {
            $lastKey = $Matches[1]
            $fm[$lastKey] = $Matches[2]
        }
        elseif ($lastKey -and $line -match '^\s+-\s+(.+?)\s*$') {
            # Block-style list item ("reviewed_files:" followed by "  - path").
            $fm[$lastKey] = (@($fm[$lastKey], $Matches[1]) | Where-Object { $_ }) -join ', '
        }
    }
    $body = if ($end + 1 -lt $lines.Count) { $lines[($end + 1)..($lines.Count - 1)] -join "`n" } else { '' }
    [pscustomobject]@{ Fields = $fm; Body = $body }
}

# --- 1. Changed files -------------------------------------------------------------
if (-not $Files) {
    $diff = git diff --name-only --diff-filter=ACMR "$BaseRef...HEAD" 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Fall back to a two-dot diff when there is no merge base (shallow fetch).
        $diff = git diff --name-only --diff-filter=ACMR $BaseRef HEAD 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Could not diff against '$BaseRef': $diff" }
    }
    $Files = @($diff | Where-Object { $_ })
}
# Accept "a,b" as well as an array: 'pwsh -File' cannot pass arrays.
$Files = @($Files | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().Replace('\', '/') } | Where-Object { $_ })

Write-Host "Changed files ($($Files.Count)):"
$Files | ForEach-Object { Write-Host "  $_" }
Write-Host ''

$reportPrefix = $ReportFolder.TrimEnd('/') + '/'
$reports = @($Files | Where-Object {
        $_.StartsWith($reportPrefix) -and $_ -like '*.md' -and
        (Split-Path $_ -Leaf) -notin @('README.md', '_TEMPLATE.md')
    })
$rules = @($Files | Where-Object { $_ -like 'custom/knowledge/*.md' })

# --- 2-3. Review reports ----------------------------------------------------------
if ($reports.Count -eq 0) {
    Add-GateError "No review receipt found. Ask your agent to run the BCQuality Review and commit the report to $reportPrefix<your-slug>.md."
}

foreach ($report in $reports) {
    if (-not (Test-Path -LiteralPath $report)) { Add-GateError 'Report is listed as changed but not found in the checkout.' $report; continue }
    $parsed = Read-Frontmatter $report
    if (-not $parsed) {
        Add-GateError "No frontmatter. The report must start with a '---' block (reviewed_with, reviewed_files, outcome, blockers)." $report
        continue
    }
    $fm = $parsed.Fields

    foreach ($key in 'reviewed_with', 'reviewed_files', 'outcome', 'blockers') {
        if (-not $fm.Contains($key) -or [string]::IsNullOrWhiteSpace($fm[$key])) {
            Add-GateError "Frontmatter field '$key' is missing or empty." $report
        }
    }

    if ($fm.Contains('blockers') -and $fm['blockers']) {
        $count = 0
        if (-not [int]::TryParse($fm['blockers'], [ref] $count) -or $count -lt 0) {
            Add-GateError "'blockers' must be a whole number, got '$($fm['blockers'])'." $report
        }
        elseif ($count -gt 0) {
            Add-GateError "Review has $count open blocker(s). Give each one a verdict in '## Verdicts' (accept: <reason> or reject: <reason>), or fix the code and rerun the review." $report
        }
    }

    if ($fm.Contains('outcome') -and $fm['outcome']) {
        switch ($fm['outcome']) {
            'completed' { }
            'partial' { Add-GateWarning 'Review outcome is partial: not every check finished. Accepted, but rerun if you can.' $report }
            'failed' { Add-GateError 'Review outcome is failed, so this is not a receipt. Rerun the BCQuality Review.' $report }
            default { Add-GateError "'outcome' must be completed, partial or failed, got '$($fm['outcome'])'." $report }
        }
    }

    foreach ($heading in '## Blockers', '## Findings', '## Verdicts') {
        if ($parsed.Body -notmatch "(?m)^$([regex]::Escape($heading))\s*$") {
            Add-GateError "Missing section '$heading'." $report
        }
    }
}

# --- 4. Path restriction ----------------------------------------------------------
if ($RestrictPaths) {
    $outside = @($Files | Where-Object { -not ($_.StartsWith('custom/knowledge/') -or $_.StartsWith($reportPrefix)) })
    foreach ($f in $outside) {
        Add-GateError "This PR may only change custom/knowledge/ (your rule) and $reportPrefix (your report). Remove this file from the PR." $f
    }
}

# --- 5. Rule files follow READ ----------------------------------------------------
foreach ($rule in $rules) {
    if (-not (Test-Path -LiteralPath $rule)) { continue }
    if ($rule -notmatch '^custom/knowledge/[^/]+/[^/]+\.md$') {
        Add-GateError 'Rules must live at custom/knowledge/<domain>/<slug>.md.' $rule
    }
    $parsed = Read-Frontmatter $rule
    if (-not $parsed) { Add-GateError 'Rule has no frontmatter block; BCQuality would skip it.' $rule; continue }
    foreach ($key in 'bc-version', 'domain', 'keywords', 'technologies', 'countries', 'application-area') {
        if (-not $parsed.Fields.Contains($key) -or $parsed.Fields[$key] -in @('', '[]')) {
            Add-GateError "Rule frontmatter field '$key' is missing or empty; BCQuality would skip this rule." $rule
        }
    }
    if ($parsed.Body -notmatch '(?m)^## Description\s*$') { Add-GateError "Rule is missing the required '## Description' section." $rule }
    if ($parsed.Body -match '(?m)^\s*(```|~~~)') { Add-GateError 'Rules must not contain fenced code blocks. Put code in a sibling <slug>.good.al / <slug>.bad.al file.' $rule }
}

# --- Result -----------------------------------------------------------------------
$summary = [System.Text.StringBuilder]::new()
if ($script:Errors.Count -eq 0) {
    [void] $summary.AppendLine('## ✅ Review receipt accepted')
    [void] $summary.AppendLine()
    $reports | ForEach-Object { [void] $summary.AppendLine("- ``$_``") }
}
else {
    [void] $summary.AppendLine('## ❌ Review receipt gate failed')
    [void] $summary.AppendLine()
    $script:Errors | ForEach-Object { [void] $summary.AppendLine("- $_") }
}
if ($script:Warnings.Count) {
    [void] $summary.AppendLine()
    [void] $summary.AppendLine('**Warnings**')
    $script:Warnings | ForEach-Object { [void] $summary.AppendLine("- $_") }
}

Write-Host $summary.ToString()
if ($env:GITHUB_STEP_SUMMARY) { $summary.ToString() | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8 }

exit $(if ($script:Errors.Count) { 1 } else { 0 })
