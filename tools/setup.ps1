param(
  [string]$Root = (Split-Path $PSScriptRoot -Parent),
  [string]$UserName,
  [string]$Email,
  [switch]$Online,
  [string]$AgentSkillsRoot,
  [string]$CodexSkillsRoot
)

$ErrorActionPreference = 'Stop'
try {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git from https://git-scm.com/downloads, reopen PowerShell, and retry. You can also contribute with the GitHub website; see docs/onboarding.md.' }
  $Root = (Resolve-Path -LiteralPath $Root).Path
  if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) { throw 'Run setup from a cloned vault repository. It will not overwrite or initialize another folder.' }
  foreach ($setting in @(@('user.name',$UserName),@('user.email',$Email))) {
    if ($setting[1]) {
      & git -C $Root config --local $setting[0] $setting[1]
      if ($LASTEXITCODE -ne 0) { throw "Could not configure $($setting[0])." }
    }
  }
  $helper = & git -C $Root config --get credential.helper
  if (-not $helper -and (Get-Command git-credential-manager -ErrorAction SilentlyContinue)) {
    & git -C $Root config --local credential.helper manager
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure the local credential helper.' }
  }
  $source = Join-Path $Root 'skills/posting-vault-notes/SKILL.md'
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $text = [IO.File]::ReadAllText($source, $utf8)
  $text = $text.Replace('%USERPROFILE%\Unity-Dev-Notes',$Root).Replace('$env:USERPROFILE\Unity-Dev-Notes',$Root)
  $codexRoot = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
  if (-not $AgentSkillsRoot) { $AgentSkillsRoot = Join-Path $env:USERPROFILE '.agents/skills' }
  if (-not $CodexSkillsRoot) { $CodexSkillsRoot = Join-Path $codexRoot 'skills' }
  $destinations = @((Join-Path $AgentSkillsRoot 'posting-vault-notes'),(Join-Path $CodexSkillsRoot 'posting-vault-notes')) | Select-Object -Unique
  foreach ($dest in $destinations) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $target = Join-Path $dest 'SKILL.md'
    if (Test-Path -LiteralPath $target) {
      if ([IO.File]::ReadAllText($target,$utf8) -ne $text) {
        Copy-Item -LiteralPath $target -Destination ($target + '.before-setup-' + (Get-Date -Format 'yyyyMMddHHmmssfff'))
      }
    }
    [IO.File]::WriteAllText($target,$text,$utf8)
  }
  Write-Output 'Local setup complete. Global Git identity and Windows security settings were not changed.'
  Write-Output 'Start a new agent conversation to load the skill. Online account/write access is checked only with -Online.'
  & (Join-Path $Root 'tools/vault.ps1') doctor -Online:$Online
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} catch {
  Write-Output "ERROR: $($_.Exception.Message)"
  exit 1
}
