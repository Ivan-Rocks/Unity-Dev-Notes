<#
.SYNOPSIS
  Unity Dev Notes vault git automation (P0).

.DESCRIPTION
  Subcommands:
    sync                     Fetch origin; fast-forward default branch, or rebase a feature branch.
    index                    Regenerate notes/index.json from notes/**/*.md.
    validate -File <path>    Validate a note's frontmatter.
    post -File <path>        Publish a draft note: sync -> id check -> branch -> write -> index -> commit -> push -> create/reuse actual PR (pending review).
                             Options: -DryRun (plan only), -NoPush (skip push).
    cleanup                  Delete local note/* branches already merged into origin/main.
    doctor [-Online]         Check local setup; optionally verify GitHub account/write access.
    init                     Install the skill and configure repository-local identity.
    search -Query <text>     Find notes for an error and show known applicability.
    pr                       Retry an actual PR for the current uploaded branch.
    feedback                 Preview or send a failure report for an existing note.

  Compatible with Windows PowerShell 5.1. Keep script messages ASCII to avoid
  encoding issues; note *content* is read/written as UTF-8.

.EXAMPLE
  pwsh -File tools/vault.ps1 sync
  pwsh -File tools/vault.ps1 post -File C:\tmp\my-note.md
  pwsh -File tools/vault.ps1 post -File C:\tmp\my-note.md -DryRun
#>
param(
  [Parameter(Position=0)][ValidateSet('sync','index','validate','post','cleanup','doctor','init','search','pr','feedback')][string]$Command,
  [string]$File,
  [switch]$NoPush,
  [switch]$DryRun,
  [switch]$Update,
  [string]$Query,
  [string]$NoteId,
  [string]$Message,
  [string]$UnityVersion,
  [switch]$IncludeDrafts,
  [switch]$Interactive,
  [switch]$Json,
  [switch]$Online,
  [string]$UserName,
  [string]$Email
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
  if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') { throw "No YAML frontmatter in $Path" }
  $fm = @{}; $closed = $false; $listKey = ''
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim() -eq '---') { $closed = $true; break }
    # Only root keys belong to note metadata; nested source fields must not overwrite them.
    if ($line -match '^([A-Za-z0-9_]+)\s*:\s*(.*)$') {
      $key = $Matches[1]; $value = $Matches[2].Trim()
      if ($fm.ContainsKey($key)) { throw "Duplicate frontmatter field: $key" }
      if ($value.Length -ge 2 -and (($value.StartsWith("'") -and $value.EndsWith("'")) -or ($value.StartsWith('"') -and $value.EndsWith('"')))) {
        $value = $value.Substring(1, $value.Length - 2)
      }
      $fm[$key] = $value; $listKey = ''
      if ($key -in @('tags','related') -and -not $value) { $listKey = $key }
    } elseif ($listKey -and $line -match '^\s+-\s+(.+)$') {
      $item = $Matches[1].Trim().Trim('"').Trim("'")
      if ($fm[$listKey]) { $fm[$listKey] += ',' }
      $fm[$listKey] += $item
    }
  }
  if (-not $closed) { throw "Unclosed YAML frontmatter in $Path" }
  return $fm
}

function Parse-Tags {
  param([string]$Val)
  if (-not $Val) { return @() }
  $t = $Val.Trim()
  if ($t -eq '[]') { return @() }
  if ($t -match '^\[(.*)\]$') { $t = $Matches[1] }
  return @($t -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") } | Where-Object { $_ -ne '' })
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
  foreach ($key in @('created','updated')) {
    $parsedDate = [datetime]::MinValue
    if ($Fm[$key] -and -not [datetime]::TryParseExact($Fm[$key], 'yyyy-MM-dd', [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsedDate)) { $errs += "invalid date: $key" }
  }
  foreach ($key in $EvidenceEnums.Keys) {
    if ($Fm[$key] -and $EvidenceEnums[$key] -notcontains $Fm[$key]) { $errs += "invalid ${key}: $($Fm[$key])" }
  }
  foreach ($key in @('render_pipeline','platform','device','prerequisites')) {
    if ($Fm[$key] -match '\u5f85\u586b\u5199') { $errs += "replace or omit placeholder: $key" }
  }
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
      throw "Cannot fast-forward (local diverged). Resolve manually: git rebase origin/$default"
    } else {
      Write-Output "synced: $($r.Out)"
    }
  } else {
    $r = Run-Git $Root @('rebase',"origin/$default")
    if ($r.Code -ne 0) {
      throw "Rebase conflict on $cur; resolve manually, then git rebase --continue"
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
  $items = @(); $seen = @{}
  foreach ($f in @(Get-ChildItem $notesDir -Recurse -Filter '*.md' | Sort-Object FullName)) {
    $txt = [System.IO.File]::ReadAllText($f.FullName, $Utf8NoBom)
    if ($txt -notmatch '^\s*---') { continue }
    $fm = Read-Frontmatter $f.FullName
    if (-not $fm['id']) { continue }
    $errs = @(Validate-Frontmatter $fm)
    if ($errs.Count) { throw "Invalid indexed note $($f.Name): $($errs -join '; ')" }
    if ($seen.ContainsKey($fm['id'])) { throw "Duplicate note id: $($fm['id'])" }
    $seen[$fm['id']] = $true
    $item = [ordered]@{
      id = $fm['id']; path = ($f.FullName.Substring($notesDir.Length + 1) -replace '\\','/')
      title = $fm['title']; category = $fm['category']; status = $fm['status']
      tags = @(Parse-Tags $fm['tags']); updated = $fm['updated']; summary = Get-Summary $f.FullName
    }
    foreach ($field in $ContextFields) { $item[$field] = $fm[$field] }
    $items += [pscustomobject]$item
  }
  $data = [ordered]@{ generated = (Get-Date -Format 'yyyy-MM-dd'); notes = @($items | Sort-Object id) }
  [System.IO.File]::WriteAllText((Join-Path $notesDir 'index.json'), ($data | ConvertTo-Json -Depth 8), $Utf8NoBom)
  Write-Output "index.json regenerated with $($items.Count) note(s)."
}

function Test-Note {
  param([string]$Path)
  $fm = Read-Frontmatter $Path
  $errs = @(Validate-Frontmatter $fm)
  if ([System.IO.Path]::GetFileNameWithoutExtension($Path) -ne $fm['id']) { $errs += 'id must match the filename' }
  if ($errs.Count -eq 0) { Write-Output "PASS: $Path" }
  else {
    Write-Output "FAIL: $Path"
    $errs | ForEach-Object { Write-Output "  - $_" }
    throw "Note validation failed."
  }
}

function Publish-Note {
  param([string]$Root, [string]$File, [switch]$NoPush, [switch]$DryRun, [switch]$Update)
  if (-not $File) { throw 'post requires -File <path-to-draft.md>' }
  $draftPath = (Resolve-Path -LiteralPath $File).Path
  $fm = Read-Frontmatter $draftPath
  $errs = @(Validate-Frontmatter $fm)
  if ($errs.Count -gt 0) { throw ("draft invalid: " + ($errs -join '; ')) }

  if ([System.IO.Path]::GetFileNameWithoutExtension($draftPath) -ne $fm['id']) { throw 'id must match the filename' }
  if ($fm['status'] -notin @('draft','review')) { throw 'Post accepts draft/review only; an admin formalizes notes during review.' }
  $id       = $fm['id']
  $title    = $fm['title']
  $category = $fm['category']
  $targetDir  = Join-Path $Root "notes\$category"
  $targetFile = Join-Path $targetDir "$id.md"
  $branch   = if ($Update) { "note/$id-update-" + (Get-Date -Format 'yyyyMMddHHmmssfff') } else { "note/$id" }

  if ($DryRun) {
    Write-Output "[dry-run] target   : $targetFile"
    Write-Output "[dry-run] branch   : $branch (status=$($fm['status']))"
    Write-Output "[dry-run] steps    : fetch -> merge --ff-only main -> id-check -> checkout -b -> copy -> index -> commit -> push -> create-or-reuse PR (pending review)"
    return
  }

  Assert-CleanVault $Root
  Assert-Identity $Root
  # Fail before changing a branch if automatic PR creation cannot be authenticated.
  if (-not $NoPush) { $null = Get-GitHubContext $Root; $null = Get-GitHubHeaders $Root }
  Sync-Base $Root

  $existing = @(Get-ChildItem (Join-Path $Root 'notes') -Recurse -Filter "$id.md" -ErrorAction SilentlyContinue)
  if ($Update) {
    if ($existing.Count -ne 1) { throw "Update requires exactly one existing note with id '$id'." }
    $old = Read-Frontmatter $existing[0].FullName
    if ($old['category'] -ne $category) { throw 'Update cannot move a note to another category.' }
    if ($old['created'] -ne $fm['created']) { throw 'Update must preserve the original created date.' }
    if ($fm['updated'] -lt $old['updated']) { throw 'updated must not move backwards.' }
  } elseif ($existing.Count -gt 0) { throw "Note id '$id' already exists. Use post -Update -File <revised-draft.md>." }

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

  Complete-PullRequest $Root $branch $title

}

. (Join-Path $PSScriptRoot 'vault-features.ps1')

if ($MyInvocation.InvocationName -ne '.') {
try {
  $root = Get-VaultRoot
  switch ($Command) {
    'sync'     { Sync-Vault $root }
    'cleanup'  { Cleanup-Vault $root }
    'index'    { Build-Index $root }
    'validate' { if (-not $File) { throw 'validate requires -File <path>' }; Test-Note $File }
    'post'     { Publish-Note -Root $root -File $File -NoPush:$NoPush -DryRun:$DryRun -Update:$Update }
    'doctor'   { Test-VaultEnvironment $root -Online:$Online -Json:$Json }
    'init'     { & (Join-Path $PSScriptRoot 'setup.ps1') -Root $root -UserName $UserName -Email $Email -Online:$Online; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }
    'search'   { Search-Vault $root -Query $Query -File $File -UnityVersion $UnityVersion -IncludeDrafts:$IncludeDrafts -Interactive:$Interactive -Json:$Json }
    'pr'       { Assert-FeatureBranch $root; $current = (Run-Git $root @('branch','--show-current')).Out.Trim(); $title = (Run-Git $root @('log','-1','--format=%s')).Out.Trim() -replace '^note:\s*',''; Complete-PullRequest $root $current $title }
    'feedback' { Send-NoteFeedback $root -NoteId $NoteId -Message $Message -DryRun:$DryRun }
    default    { throw "Unknown command: $Command" }
  }
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}

}
