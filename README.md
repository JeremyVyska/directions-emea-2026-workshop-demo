# AmuseYou: review-receipt gate demo

Demo repo for the Directions EMEA 2026 lab **"Agentic as a Team Sport"**. It shows what the take-home pipeline looks like in an ordinary AL app repo.

- The review runs **locally**, by each developer's own agent, using [BCQuality](https://github.com/microsoft/BCQuality) (here: the workshop copy, https://github.com/JeremyVyska/directions-emea-2026-workshop).
- The agent commits its report to `reviews/`.
- The PR check (`.github/workflows/review-receipt-gate.yml` → `.github/scripts/check-review-receipt.ps1`) only checks that the receipt exists and has no open blockers. No LLM, no API key, no secrets in CI.

Agents learn how to produce the receipt from [`AGENTS.md`](AGENTS.md). See the pull requests: the same change with and without a receipt.
