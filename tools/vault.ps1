<#
.SYNOPSIS
  Unity Dev Notes vault git automation (P0).

.DESCRIPTION
  Subcommands:
    sync                     Fetch origin; fast-forward default branch, or rebase a feature branch.
    index                    Regenerate notes/index.json from notes/**/*.md.
    validate -File <path>    Validate a note's frontmatter.
    post -File <path>        Publish a draft note: sync -> id check -> branch -> write -> index -> commit -> push -> PR URL.
                             Options: -DryRun (plan only), -NoPush (skip push).
    cleanup                  Delete local note/* branches already merged into origin/main.

  Compatible with Windows PowerShell 5.1. Keep script messages ASCII to avoid
  encoding issues; note *content* is read/written as UTF-8.

.EXAMPLE
  pwsh -File tools/vault.ps1 sync
  pwsh -File tools/vault.ps1 post -File C:\tmp\my-note.md
  pwsh -File tools/vault.ps1 post -File C:\tmp\my-note.md -DryRun
#>
param(
  [Parameter(Position=0)][ValidateSet('sync','index','validate','post','cleanup')][string]$Command,
  [string]$File,
  [switch]$NoPush,
  [switch]$DryRun
)

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Categories = @('bugs','knowledge','how-to','snippet')
$Statuses   = @('draft','review','formalized','deprecated')

function Get-VaultRoot {
  $d = $PSScriptRoot
  while ($d) {
    if ((Test-Path (Join-Path $d '.git')) -and (Test-Path (Join-Path $d 'notes')) -and (Test-Path (Join-Path $d 'docs'))) { return $d }
    $parent = Split-Path $d -Parent
    if (-not $parent -or $parent -eq $d) { break }
    $d = $parent
  }
  throw 'Script must live inside the vault repo (need .git + notes/ + docs/).'
}

function Run-Git {
  param([string]$Dir, [string[]]$GitArgs)
  $out = & git -C $Dir @GitArgs 2>&1
  return [pscustomobject]@{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}

function Get-DefaultBranch {
  param([string]$Root)
  $r = Run-Git $Root @('symbolic-ref','--short','refs/remotes/origin/HEAD')
  $name = $r.Out.Trim()
  if ($r.Code -eq 0 -and $name -match 'origin/(.+)') { return $Matches[1] }
  $r2 = Run-Git $Root @('ls-remote','--symref','origin','HEAD')
  if ($r2.Code -eq 0) {
    $m = [regex]::Match($r2.Out, 'refs/heads/(\S+)\s+HEAD')
    if ($m.Success) { return $m.Groups[1].Value }
  }
  return 'main'
}

function Read-Frontmatter {
  param([string]$Path)
  $text = [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
  $lines = $text -split "`r?`n"
  if ($lines.Count -lt 2 -or $lines[0].Trim() -ne '---') { throw "No YAML frontmatter in $Path" }
  $fm = @{}
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim() -eq '---') { break }
    if ($line -match '^\s*([A-Za-z0-9_]+)\s*:\s*(.*)$') { $fm[$Matches[1]] = $Matches[2].Trim() }
  }
  return $fm
}

function Parse-Tags {
  param([string]$Val)
  if (-not $Val) { return @() }
  $t = $Val.Trim()
  if ($t -eq '[]') { return @() }
  if ($t -match '^\[(.*)\]$') { $t = $Matches[1] }
  return @($t -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Get-Summary {
  param([string]$Path)
  $text = [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
  $lines = $text -split "`r?`n"
  $inSummary = $false; $parts = @()
  foreach ($line in $lines) {
    if ($line -match '^##\s+Summary\s*$') { $inSummary = $true; continue }
    if ($inSummary) {
      if ($line -match '^##\s+') { break }
      $t = $line.Trim()
      if ($t) { $parts += $t }
    }
  }
  return ($parts -join ' ')
}

function Validate-Frontmatter {
  param([hashtable]$Fm)
  $errs = @()
  foreach ($req in @('id','title','category','status','created','updated')) {
    if (-not $Fm[$req]) { $errs += "missing required field: $req" }
  }
  if ($Fm['id'] -and $Fm['id'] -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[a-z0-9-]+$') { $errs += "invalid id: $($Fm['id'])" }
  if ($Fm['category'] -and $Categories -notcontains $Fm['category']) { $errs += "invalid category: $($Fm['category'])" }
  if ($Fm['status'] -and $Statuses -notcontains $Fm['status']) { $errs += "invalid status: $($Fm['status'])" }
  return $errs
}

function Sync-Base {
  param([string]$Root)
  $r = Run-Git $Root @('fetch','origin','--prune')
  if ($r.Code -ne 0) { throw "fetch failed: $($r.Out)" }
  $default = Get-DefaultBranch $Root
  $cur = (Run-Git $Root @('branch','--show-current')).Out.Trim()
  if ($cur -ne $default) {
    $r = Run-Git $Root @('checkout',$default)
    if ($r.Code -ne 0) { throw "checkout $default failed: $($r.Out)" }
  }
  $r = Run-Git $Root @('merge','--ff-only',"origin/$default")
  if ($r.Code -ne 0) { throw "cannot fast-forward $default onto origin/$default (local diverged): $($r.Out)" }
  Write-Output "base synced: $default -> origin/$default"
}

function Sync-Vault {
  param([string]$Root)
  $r = Run-Git $Root @('fetch','origin','--prune')
  if ($r.Code -ne 0) { throw "fetch failed: $($r.Out)" }
  $default = Get-DefaultBranch $Root
  $cur = (Run-Git $Root @('branch','--show-current')).Out.Trim()
  $behind = (Run-Git $Root @('rev-list','--count',"HEAD..origin/$default")).Out.Trim()
  $ahead  = (Run-Git $Root @('rev-list','--count',"origin/$default..HEAD")).Out.Trim()
  Write-Output "current=$cur default=$default behind=$behind ahead=$ahead"
  if ($cur -eq $default) {
    $r = Run-Git $Root @('merge','--ff-only',"origin/$default")
    if ($r.Code -ne 0) {
      Write-Output "WARNING: cannot fast-forward (local diverged). Resolve manually: git rebase origin/$default"
    } else {
      Write-Output "synced: $($r.Out)"
    }
  } else {
    $r = Run-Git $Root @('rebase',"origin/$default")
    if ($r.Code -ne 0) {
      Write-Output "rebase conflict on $cur; resolve manually, then git rebase --continue"
    } else {
      Write-Output "rebased $cur onto origin/$default"
    }
  }
}

function Cleanup-Vault {
  param([string]$Root)
  $r = Run-Git $Root @('fetch','origin','--prune')
  if ($r.Code -ne 0) { throw "fetch failed: $($r.Out)" }
  $default = Get-DefaultBranch $Root
  $cur = (Run-Git $Root @('branch','--show-current')).Out.Trim()
  if ($cur -ne $default) {
    $r = Run-Git $Root @('checkout',$default)
    if ($r.Code -ne 0) { throw "checkout $default failed: $($r.Out)" }
  }
  $r = Run-Git $Root @('merge','--ff-only',"origin/$default")
  if ($r.Code -ne 0) { throw "cannot fast-forward ${default}: $($r.Out)" }

  $merged = Run-Git $Root @('branch','--merged',"origin/$default")
  $toDelete = @()
  foreach ($line in ($merged.Out -split "`n")) {
    $name = $line.Trim().TrimStart('*').Trim()
    if ($name -like 'note/*') { $toDelete += $name }
  }
  if ($toDelete.Count -eq 0) {
    Write-Output "cleanup: no merged note/* branches to delete."
    return
  }
  foreach ($b in $toDelete) {
    $r = Run-Git $Root @('branch','-d',$b)
    if ($r.Code -eq 0) { Write-Output "deleted local branch: $b" }
    else { Write-Output "kept (not fully merged): $b" }
  }
  Write-Output "cleanup done."
}

function Escape-Json {
  param([string]$s)
  if ($null -eq $s) { return '' }
  return $s.Replace('\','\\').Replace('"','\"').Replace("`r",'\r').Replace("`n",'\n').Replace("`t",'\t')
}

function Build-Index {
  param([string]$Root)
  $notesDir = Join-Path $Root 'notes'
  $items = @()
  $files = @(Get-ChildItem $notesDir -Recurse -Filter '*.md')
  foreach ($f in $files) {
    $txt = [System.IO.File]::ReadAllText($f.FullName, $Utf8NoBom)
    if ($txt -notmatch '^\s*---') { continue }   # skip non-note md (e.g. notes/README.md)
    $fm = Read-Frontmatter $f.FullName
    if (-not $fm['id']) { continue }
    $rel = $f.FullName.Substring($notesDir.Length + 1) -replace '\\','/'
    $items += [pscustomobject]@{
      id       = $fm['id']
      path     = $rel
      title    = $fm['title']
      category = $fm['category']
      status   = $fm['status']
      tags     = @(Parse-Tags $fm['tags'])
      updated  = $fm['updated']
      summary  = Get-Summary $f.FullName
    }
  }
  $items = @($items | Sort-Object id)

  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('{')
  [void]$sb.AppendLine('  "generated": "' + (Get-Date -Format 'yyyy-MM-dd') + '",')
  [void]$sb.AppendLine('  "notes": [')
  for ($i = 0; $i -lt $items.Count; $i++) {
    $it = $items[$i]
    $tagsJson = (@($it.tags) | ForEach-Object { '"' + (Escape-Json $_) + '"' }) -join ', '
    [void]$sb.AppendLine('    {')
    [void]$sb.AppendLine('      "id": "'       + (Escape-Json $it.id)       + '",')
    [void]$sb.AppendLine('      "path": "'     + (Escape-Json $it.path)     + '",')
    [void]$sb.AppendLine('      "title": "'    + (Escape-Json $it.title)    + '",')
    [void]$sb.AppendLine('      "category": "' + (Escape-Json $it.category) + '",')
    [void]$sb.AppendLine('      "status": "'   + (Escape-Json $it.status)   + '",')
    [void]$sb.AppendLine('      "tags": [' + $tagsJson + '],')
    [void]$sb.AppendLine('      "updated": "'  + (Escape-Json $it.updated)  + '",')
    [void]$sb.AppendLine('      "summary": "'  + (Escape-Json $it.summary)  + '"')
    if ($i -lt $items.Count - 1) { [void]$sb.AppendLine('    },') } else { [void]$sb.AppendLine('    }') }
  }
  [void]$sb.AppendLine('  ]')
  [void]$sb.Append('}')
  $json = $sb.ToString()
  [System.IO.File]::WriteAllText((Join-Path $notesDir 'index.json'), $json, $Utf8NoBom)
  Write-Output "index.json regenerated with $($items.Count) note(s)."
}

function Test-Note {
  param([string]$Path)
  $fm = Read-Frontmatter $Path
  $errs = @(Validate-Frontmatter $fm)
  if ($errs.Count -eq 0) { Write-Output "PASS: $Path" }
  else {
    Write-Output "FAIL: $Path"
    $errs | ForEach-Object { Write-Output "  - $_" }
  }
}

function Publish-Note {
  param([string]$Root, [string]$File, [switch]$NoPush, [switch]$DryRun)
  if (-not $File) { throw 'post requires -File <path-to-draft.md>' }
  $draftPath = (Resolve-Path -LiteralPath $File).Path
  $fm = Read-Frontmatter $draftPath
  $errs = @(Validate-Frontmatter $fm)
  if ($errs.Count -gt 0) { throw ("draft invalid: " + ($errs -join '; ')) }

  $id       = $fm['id']
  $title    = $fm['title']
  $category = $fm['category']
  $targetDir  = Join-Path $Root "notes\$category"
  $targetFile = Join-Path $targetDir "$id.md"
  $branch   = "note/$id"

  if ($DryRun) {
    Write-Output "[dry-run] target   : $targetFile"
    Write-Output "[dry-run] branch   : $branch (status=$($fm['status']))"
    Write-Output "[dry-run] steps    : fetch -> merge --ff-only main -> id-check -> checkout -b -> copy -> index -> commit -> push"
    return
  }

  Sync-Base $Root

  $existing = @(Get-ChildItem (Join-Path $Root 'notes') -Recurse -Filter "$id.md" -ErrorAction SilentlyContinue)
  if ($existing.Count -gt 0) { throw "Note id '$id' already exists: $($existing[0].FullName)" }

  $r = Run-Git $Root @('checkout','-b',$branch)
  if ($r.Code -ne 0) { throw "checkout -b $branch failed: $($r.Out)" }

  New-Item -ItemType Directory -Force $targetDir | Out-Null
  Copy-Item -LiteralPath $draftPath -Destination $targetFile -Force

  Build-Index $Root

  $r = Run-Git $Root @('add','--',"notes/$category/$id.md",'notes/index.json')
  if ($r.Code -ne 0) { throw "git add failed: $($r.Out)" }
  $r = Run-Git $Root @('commit','-m',"note: $title")
  if ($r.Code -ne 0) { throw "git commit failed: $($r.Out)" }

  if ($NoPush) {
    Write-Output "committed on $branch (push skipped by -NoPush)."
    return
  }

  $r = Run-Git $Root @('push','-u','origin',$branch)
  if ($r.Code -ne 0) { throw "git push failed: $($r.Out)" }
  Write-Output "pushed branch $branch."

  $default = Get-DefaultBranch $Root
  $remoteUrl = (Run-Git $Root @('config','--get','remote.origin.url')).Out.Trim()
  if ($remoteUrl -match 'github\.com[:/](.+?)(\.git)?$') {
    $repoPath = $Matches[1]
    Write-Output "PR URL: https://github.com/$repoPath/compare/$default...$branch`?expand=1"
  } else {
    Write-Output "Open a PR from $branch into $default manually."
  }
}

try {
  $root = Get-VaultRoot
  switch ($Command) {
    'sync'     { Sync-Vault $root }
    'cleanup'  { Cleanup-Vault $root }
    'index'    { Build-Index $root }
    'validate' { if (-not $File) { throw 'validate requires -File <path>' }; Test-Note $File }
    'post'     { Publish-Note -Root $root -File $File -NoPush:$NoPush -DryRun:$DryRun }
    default    { throw "Unknown command: $Command" }
  }
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}
