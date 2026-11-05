---
name: posting-vault-notes
description: Use when posting or syncing notes in a git-backed knowledge vault (e.g. Unity Dev Notes), when git push is rejected as non-fast-forward after a colleague pushed first, or when searching errors, correcting an existing note, reporting a failed solution, or when a notes index (index.json) needs regeneration.
---

# Posting Vault Notes

## Overview

A note vault is a git repo of Markdown notes plus a generated `notes/index.json`. Two rules keep it from breaking under concurrent edits: **never commit to `main` directly** (every note goes on a `note/<id>` branch through a PR), and **regenerate the index, never hand-edit or merge it**.

## When to Use

- Posting a new note to the vault, or syncing the vault repo before any manual git work.
- `git push` rejected: `non-fast-forward` / `src refspec main does not match any` / `failed to push`.
- A colleague pushed first and you forgot to pull.
- `notes/index.json` is stale (missing recent notes) and needs regeneration.
- Local `note/*` branches pile up after merges and need cleanup.

Not for: editing `docs/` contracts, or changes outside `notes/`.

## Core Workflow

Prefer the repo script `tools/vault.ps1` over raw git. It bundles sync + branch + index + push + actual PR creation in one step.

1. **Write the draft** as a `.md` with frontmatter (`id`, `title`, `category`, `status`, `created`, `updated`, `source`), per `docs/note-spec.md` and a template in `docs/templates/`.
2. **Show the draft and wait for confirmation.** Present the note in chat and ask the user to decide "发 / 改 / 不发". Do NOT run `post` until the user confirms; apply any edits they request first.
3. **Validate**: `tools/vault.ps1 validate -File <draft>`
4. **Post** (sync → id-check → branch → write → regenerate index → commit → push):
   `tools/vault.ps1 post -File <draft>`
5. **Report the actual PR** from the printed `/pull/<number>` URL and the `PENDING_REVIEW` state. Do not claim the note is merged. If `PR_PENDING` is printed, keep the current branch and retry `vault.ps1 pr`; do not repost the same id. An admin formalizes and merges the note.

## Search first, setup only when needed

- For a pasted error, use `vault.ps1 search -Query <text>` or `search -File <log.txt>`; add `-Json` for agent output. Default results are formalized only; add `-IncludeDrafts` explicitly for draft evidence. Deprecated notes are excluded.
- Show the note's environment and verification fields to the user. Missing fields are unknown, and an approved note is not automatically validated on every version. This is local keyword search, not a claim of exhaustive or semantic retrieval.
- Run `doctor` for local configuration and `doctor -Online` for actual GitHub account/write-access checks. `setup.ps1` installs this skill with the chosen repository path and configures only repository-local identity. Do not invent a name/email or overwrite global identity.
- A note can have `diagnosis: unknown` and `resolution: workaround`. Preserve uncertainty; never invent a root cause. Keep applicability, diagnostic steps and verification in the human-readable body. AI Prompt contains only agent operation hints.

## Correct an existing note or report a failure

- Read the original note, preserve id/category/created, update the updated date, and set status to draft. Show the full revision and wait for confirmation, then run `post -Update -File <revision.md>`. The update gets a new review branch; main is not directly edited.
- For failure feedback, prepare note id, actual environment, failure and expected result. Show it and wait for explicit confirmation before `feedback -NoteId <id> -Message <report>` creates an issue. Use `-DryRun` to preview without transmitting anything.
- If shell startup fails in a restricted DSH environment, report the limitation. Do not disable protections or call the note validated. Offer the documented local PowerShell or GitHub web fallback.

Run `tools/vault.ps1 sync` before ANY manual git work — it fetches and fast-forwards `main`, or rebases a feature branch. This is what makes "forgot to pull" structurally impossible.

## Quick Reference

| Command | Purpose |
| --- | --- |
| `vault.ps1 sync` | fetch + fast-forward main / rebase feature branch |
| `vault.ps1 index` | regenerate `notes/index.json` from `notes/**/*.md` |
| `vault.ps1 validate -File <draft>` | check frontmatter |
| `vault.ps1 post -File <draft>` | publish a confirmed draft and create/reuse its PR |
| `vault.ps1 post -Update -File <revision>` | submit a confirmed correction to an existing note |
| `vault.ps1 pr` | retry only the review request on the current uploaded branch |
| `vault.ps1 search -Query <error>` | local error/keyword search with applicability |
| `vault.ps1 doctor -Online` | verify active GitHub identity and repository write access |
| `vault.ps1 feedback -NoteId <id> -Message <report> -DryRun` | preview failure feedback |
| `vault.ps1 post -File <draft> -DryRun` | plan only, no side effects |
| `vault.ps1 post -File <draft> -NoPush` | commit on branch, skip push |
| `vault.ps1 cleanup` | delete local `note/*` branches merged into origin/main |

## Implementation

### Invoke the script

The vault repo is installed at `%USERPROFILE%\Unity-Dev-Notes` (the onboarding default). If the current directory already has `notes/` + `docs/` + `.git`, you are inside the vault and may use the relative `tools/vault.ps1`; otherwise use the absolute path below.

Windows PowerShell 5.1 blocks `.ps1` by default (ExecutionPolicy). Bypass per-run — do NOT change the machine policy:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Unity-Dev-Notes\tools\vault.ps1" <cmd> -File <draft>
```

### Manual fallback (script absent)

```bash
git fetch origin --prune
git merge --ff-only origin/main        # on main
# or: git rebase origin/main           # on a feature branch
git checkout -b note/<id>
# write notes/<category>/<id>.md, then regenerate the index
git add notes/<category>/<id>.md notes/index.json
git commit -m "note: <title>"
git push -u origin note/<id>
```

### Auth (one-time)

The vault uses Git Credential Manager (`git config --global credential.helper manager`). The first `git push` opens a browser OAuth — complete it once; later pushes are passwordless. **Never store tokens in the repo or skill.** If push fails auth, verify the helper is set and re-trigger one push interactively.

## Common Mistakes

| Mistake | Fix |
| --- | --- |
| Committing straight to `main` | Always `post`, or `git checkout -b note/<id>` first. |
| Skipping sync, push rejected | Run `sync` (or let `post` sync) before committing. |
| Leaving `index.json` stale | `post` regenerates it; or run `index`. Never hand-edit; on conflict, regenerate. |
| Writing PowerShell helpers with a `$Args` parameter | It collides with the automatic `$args`; use `$GitArgs` instead. |

## Red Flags — STOP

- "It's just one small note, I'll commit to main."
- "The index can be updated later."
- "I'll push first and fix conflicts after."

All three recreate exactly what this skill prevents: a polluted `main`, a stale index, or a rejected push.
