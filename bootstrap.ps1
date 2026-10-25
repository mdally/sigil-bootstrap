# Sets Sigil up on a Windows machine: installs Git if it is missing, clones the repository into
# .\sigil, every branch a worktree beside the bare clone in .\sigil\.git, and runs the checkout's
# tools\environment_setup.ps1, which installs the other prerequisites and sets the checkout up.
# Safe to run again: it skips what is done.
#
# In PowerShell, in the folder that should hold sigil\:
#   powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/mdally/sigil-bootstrap/main/bootstrap.ps1 | iex"
#
# The repository is private, so cloning it opens a browser to sign in to GitHub, through the Git
# Credential Manager that comes with Git for Windows.
param(
    # Where to clone from; the environment tests pass a local copy.
    [string]$Repository = 'https://github.com/mdally/sigil.git'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step($message) { Write-Host "bootstrap: $message" -ForegroundColor Cyan }

# A failure's message alone, rather than PowerShell's record of where in the script it happened.
trap { Write-Host "bootstrap: error: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

# Programs report failure by exit code, which PowerShell does not stop on.
function Assert-Success($what) { if ($LASTEXITCODE -ne 0) { throw "$what failed; see above." } }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Step 'installing Git'
    # The release environment_setup.ps1 pins, which it then finds new enough. Only the winget
    # source: there the Microsoft Store source can fail its certificate check, and an install that
    # searches every source fails with it.
    winget install --id Git.Git --exact --version 2.55.0.5 --source winget --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    Assert-Success 'Installing Git'
    # The installer changed PATH for new terminals; this one reads it again.
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Test-Path sigil\.git)) {
    Write-Step "cloning $Repository into sigil\"
    git clone --bare $Repository sigil\.git
    Assert-Success 'Cloning the repository'
    # A bare clone has no remote-tracking branches, which worktrees start from.
    git -C sigil\.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git -C sigil\.git fetch origin
    Assert-Success 'Fetching the branches'
    git -C sigil\.git remote set-head origin --auto
}
if (-not (Test-Path sigil\main\.git)) {
    Write-Step 'checking out main into sigil\main'
    git -C sigil\.git worktree add (Join-Path $PWD 'sigil\main') main
    Assert-Success 'Checking out main'
    git -C sigil\main branch --set-upstream-to=origin/main main
    Assert-Success 'Tracking origin/main'
}

Write-Step 'running the checkout''s tools\environment_setup.ps1'
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PWD 'sigil\main\tools\environment_setup.ps1')
exit $LASTEXITCODE
