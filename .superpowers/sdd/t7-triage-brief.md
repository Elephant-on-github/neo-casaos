# Task brief — T7: Triage upstream CasaOS issues + PRs (PLAN.md step 8)

## Context
READ-ONLY research. No code changes, no commits, no file edits except your own report. Goal: triage upstream `IceWhaleTech/CasaOS` issues and PRs to surface a shortlist of items that would be GOOD, SAFE, small follow-up candidates for our fork (neo-casaos). This informs future work — you are NOT implementing anything.

## Requirements
1. Check tooling: is `gh` (GitHub CLI) available and authenticated (`gh auth status`)? If not available/authed, try the public GitHub REST API unauthenticated (`https://api.github.com/repos/IceWhaleTech/CasaOS/issues?state=open&per_page=100` and `.../pulls?state=open`) via a web fetch. If neither works, report BLOCKED with the reason.
2. Pull a current sample of OPEN issues and OPEN PRs from IceWhaleTech/CasaOS.
3. Triage into buckets:
   - Bugs that look small/addressable and touch dependency or build health (our lane).
   - Dependency/security-related open items.
   - Items clearly NOT relevant to a dependency-maintenance fork (large features, UI redesigns) — list count only.
4. Pick the TOP 3-5 best follow-up candidates. For each: title, number, URL, why it's a good/safe small candidate, and rough effort. Prefer items that are stale, dependency-related, or one-liners.
5. Note the fork's relationship: our fork already diverged (dep updates + go-directive bump + 4-line printf fix). Flag any upstream PR that would now CONFLICT with our changes.

## Success criteria
- A concise triage report: counts by bucket, TOP 3-5 follow-up candidates with rationale, and conflict warnings vs our branch.
- Nothing committed; no source touched.

## Report
Write the full report to `.superpowers/sdd/t7-triage-report.md`. Return only: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), a one-line summary (how many candidates shortlisted), and any concerns (e.g. gh/API unavailable).
