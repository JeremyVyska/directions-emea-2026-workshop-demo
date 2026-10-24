# AGENTS.md

Instructions for any AI agent working in this repo.

**BCQuality root** (`<BCQUALITY_ROOT>` below): your local clone of the team's BCQuality copy, outside this repo. For this demo that's a clone of https://github.com/JeremyVyska/directions-emea-2026-workshop. If you don't know where it is, ask the user once.

## Step: "Run the BCQuality Review"

Reviews the changes on the current branch with BCQuality and writes a review receipt. **Don't change any source file in this step.**

1. **BCQuality root:** `<BCQUALITY_ROOT>`. Resolve BCQuality's `skills/`, `tools/` and knowledge against that folder, never against this repo. If the folder doesn't exist, stop and say so.
2. **What to review:** the branch's changes against `origin/main`. Write `git diff origin/main...HEAD` to a temp file **outside this repo**. If the diff is empty, stop and say there's nothing to review.
3. **Prepare the index** (optional, faster): `pwsh <BCQUALITY_ROOT>/tools/Build-KnowledgeIndex.ps1`. If `pwsh` is missing or this fails, carry on; BCQuality falls back to reading its folders.
4. Read `<BCQUALITY_ROOT>/skills/entry.md` and follow it with this task context:
   ```yaml
   task-context:
     goal: Review the changes in this pull request without changing them.
     inputs-available: [pr-diff]
     technologies: [al]
     bc-version: <major version from app.json "application", e.g. 25>
     enabled-layers: [microsoft, community, custom]
     disabled-skills: []
   ```
   - The `pr-diff` input is the diff file from step 2. You may read the full changed files, and files they use, for context.
   - Add `countries` / `application-area` only if this app is limited to specific ones; otherwise omit them.
   - Consistency tip: if the team wants every agent to run the same review, fix the set of review skills with `disabled-skills`, as the workshop's `AGENTS.md` does.
5. Execute every dispatched skill as Entry and `skills/do.md` describe, reading `skills/read.md` on demand. Rules in the BCQuality copy's `custom/knowledge/` are the team's rules; where one contradicts a Microsoft or Community rule, it wins and the displaced rule is listed as suppressed. Keep raw JSON findings reports in memory or a temp folder **outside this repo**.
6. Report findings only on lines the diff changes, or code the change directly affects.
7. Write the report to `reviews/<branch-name>.md` (branch name with `/` replaced by `-`) in the format below, then reply with the report path and the counts per severity.

### Review report format

```markdown
---
reviewed_with: <agent product (model), e.g. "GitHub Copilot (agent mode, GPT-x)">
reviewed_files: [<repo-relative paths in the diff>]
bcquality_commit: <git -C <BCQUALITY_ROOT> rev-parse --short HEAD>
outcome: <completed | partial | failed>
blockers_found: <integer>
blockers: <integer, OPEN blockers: blockers_found minus those with an accept/reject verdict>
---

# BCQuality Review: <branch-name>

## Blockers

<One bullet per blocker: file:lines · message · cited rule path. "None." if none.>

## Findings

<One bullet per rule per file, most severe first: severity · confidence · file:lines · message · cited rule path (or "agent finding").>
Suppressed: <displaced rules, or None.>

## Verdicts

<`<finding>` → fix | accept: <reason> | reject: <reason>. "Not triaged yet." straight after a review.>
```

- Copy severities and rule paths from the skills' findings reports. Don't invent or adjust them.
- `blockers` counts blockers with **no** `accept` / `reject` verdict. Fix the code and rerun, or record a verdict, to get it to 0.
- If the review can't finish, write the report anyway with `outcome: partial`.
- Commit the report **in the same PR** as the change. The PR check fails without it, or while `blockers` is above 0.
