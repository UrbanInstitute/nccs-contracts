# governance/ — the committee's documentation home

This directory is the **committee-readable layer** over the
engineering record. It links into `decisions/` (ADRs), `contracts/`
(the dataset registry), and `conventions/` — it does not duplicate
them.

| File | What | Update cadence |
|---|---|---|
| `charter.md` | The governance charter | Amended by PR, typically after a committee meeting; version bumps in the header |
| `minutes/YYYY-MM-DD.md` | Meeting minutes | One file per meeting (monthly) |
| `release-notes/*.md` | Plain-language release notes per data build | One per release (§6 flow); the ONLY place release notes are authored — the website changelog page is generated from these |
| `decisions-pending.md` | Deferred committee decisions | Groomed each meeting |

Working conventions: git is the source of truth; Box carries rendered
Word exports for committee members, generated with
`python3 governance/export-box-docx.py <in.md> <out.docx>` (one-time
setup: `python3 -m pip install --user python-docx`). Meeting transcripts are NEVER
committed here (this repo is public) — they live on Box/local only.

For Claude Code sessions: this directory is the entry point for
anything data-governance-related across the multi-repo workspace;
the workspace and repo CLAUDE.md files point here.
