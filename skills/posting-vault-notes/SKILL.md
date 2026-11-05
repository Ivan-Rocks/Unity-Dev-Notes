---
name: posting-vault-notes
description: Use when posting or syncing notes in a git-backed knowledge vault (e.g. Unity Dev Notes), when git push is rejected as non-fast-forward after a colleague pushed first, or when a notes index (index.json) needs regeneration.
---

# Posting Vault Notes

## Overview

A note vault is a git repo of Markdown notes plus a generated `notes/index.json`. Two rules keep it from breaking under concurrent edits: **never commit to `main` directly** (every note goes on a `note/<id>` branch through a PR), and **regenerate the index, never hand-edit or merge it**.

## When to Use

- Posting a new note to the vault, or syncing the vault repo before any manual git work.
- `git push` rejected: `non-fast-forward` / `src refspec main does not match any` / `failed to push`.
- A colleague pushed first and you forgot to pull.
- `notes/index.json` is stale (missing recent notes) and needs regeneration.

Not for: editing `docs/` contracts, or changes outside `notes/`.

## Core Workflow

Prefer the repo script `tools/vault.ps1` over raw git. It bundles sync + branch + index + push in one step.

1. **Write the draft** as a `.md` with frontmatter (`id`, `title`, `category`, `status`, `created`, `updated`, `source`), per `docs/note-spec.md` and a template in `docs/templates/`.
2. **Validate**: `tools/vault.ps1 validate -File <draft>`
3. **Post** (sync → id-check → branch → write → regenerate index → commit → push):
   `tools/vault.ps1 post -File <draft>`
4. **Open the PR** from the printed URL. A human sets `status: formalized` before merging.

Run `tools/vault.ps1 sync` before ANY manual git work — it fetches and fast-forwards `main`, or rebases a feature branch. This is what makes "forgot to pull" structurally impossible.

## Quick Reference

| Command | Purpose |
| --- | --- |
| `vault.ps1 sync` | fetch + fast-forward main / rebase feature branch |
| `vault.ps1 index` | regenerate `notes/index.json` from `notes/**/*.md` |
| `vault.ps1 validate -File <draft>` | check frontmatter |
| `vault.ps1 post -File <draft>` | publish a draft (sync→branch→write→index→commit→push) |
| `vault.ps1 post -File <draft> -DryRun` | plan only, no side effects |
| `vault.ps1 post -File <draft> -NoPush` | commit on branch, skip push |

## Implementation

### Invoke the script

Windows PowerShell 5.1 blocks `.ps1` by default (ExecutionPolicy). Bypass per-run — do NOT change the machine policy:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tools/vault.ps1 <cmd> -File <draft>
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
