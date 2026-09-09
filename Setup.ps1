#Requires -Version 5.1
<#
.SYNOPSIS
    First-time setup for a fresh clone of The Throes of Man.
.DESCRIPTION
    Configures the two things Git cannot configure from inside the repository
    (LFS filters and the hooks path), pulls down the real asset binaries, then
    verifies the working tree is actually usable by the editor.

    Safe to re-run at any time.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File Setup.ps1
#>

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$warnings = @()

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Ok($msg)       { Write-Host "    OK   $msg" -ForegroundColor Green }
function Warn($msg)     { Write-Host "    WARN $msg" -ForegroundColor Yellow; $script:warnings += $msg }
function Die($msg)      { Write-Host "`nFAILED: $msg" -ForegroundColor Red; exit 1 }

Write-Host "The Throes of Man - clone setup" -ForegroundColor White
Write-Host "Repository: $repo"

# --- 1. Prerequisites -------------------------------------------------------
Step 1 'Checking prerequisites'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die 'git not found on PATH. Install Git for Windows: https://git-scm.com/downloads'
}
Ok (git --version)

if (-not (Get-Command git-lfs -ErrorAction SilentlyContinue)) {
    Die @'
git-lfs not found on PATH. Every binary asset in this project (.uasset, .umap,
textures, audio) is stored in Git LFS - without it you get 133-byte text
pointers instead of assets and the editor will not open the project.

Install: https://git-lfs.com  (or: winget install GitHub.GitLFS)
Then re-run this script.
'@
}
Ok (git lfs version)

# --- 2. LFS filters ---------------------------------------------------------
Step 2 'Installing Git LFS filters (global)'
git lfs install | Out-Null
if ($LASTEXITCODE -ne 0) { Die 'git lfs install failed.' }
Ok 'clean/smudge filters registered'

# --- 3. Hooks path ----------------------------------------------------------
# core.hooksPath cannot be set by the repository itself, so it must be set per
# clone. It points at .githooks/, which holds the pre-commit guard against
# committing raw binaries plus the LFS hooks.
Step 3 'Pointing Git at the tracked hooks directory'
git -C $repo config core.hooksPath .githooks
Ok "core.hooksPath = $(git -C $repo config core.hooksPath)"

# --- 4. Fetch asset binaries ------------------------------------------------
Step 4 'Downloading asset binaries from LFS (this can take a few minutes)'
git -C $repo lfs pull
if ($LASTEXITCODE -ne 0) { Die 'git lfs pull failed. Check your network and GitHub access.' }
Ok 'LFS objects pulled'

# --- 5. Verify assets are real files, not pointers --------------------------
Step 5 'Verifying assets resolved correctly'
$probe = Join-Path $repo 'ProjectFiles\Content\Characters\Mannequins\Meshes\SKM_Manny_Simple.uasset'
if (Test-Path $probe) {
    $size = (Get-Item $probe).Length
    if ($size -lt 1024) {
        Die "$probe is only $size bytes - it is still an LFS pointer. Run 'git lfs pull' manually and check for errors."
    }
    Ok ("sample asset is {0:N1} MB (real binary)" -f ($size / 1MB))
} else {
    Warn "Probe asset not found at $probe - skipped verification."
}

# --- 6. Engine check --------------------------------------------------------
Step 6 'Checking for Unreal Engine 5.8'
$found = $null
$launcher = 'C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat'
if (Test-Path $launcher) {
    $entry = (Get-Content $launcher -Raw | ConvertFrom-Json).InstallationList |
             Where-Object { $_.AppName -eq 'UE_5.8' } | Select-Object -First 1
    if ($entry) { $found = $entry.InstallLocation }
}
if (-not $found) {
    $builds = 'HKCU:\SOFTWARE\Epic Games\Unreal Engine\Builds'
    if (Test-Path $builds) {
        $p = Get-ItemProperty $builds
        $hit = $p.PSObject.Properties |
               Where-Object { $_.Value -is [string] -and $_.Value -match '5\.8' } |
               Select-Object -First 1
        if ($hit) { $found = $hit.Value }
    }
}
if ($found) {
    Ok "Unreal Engine 5.8 at $found"
} else {
    Warn @'
Could not confirm an Unreal Engine 5.8 install.

The .uproject requests engine version "5.8". If double-clicking it prompts you
to pick an engine, right-click ProjectFiles.uproject -> Switch Unreal Engine
Version and select your 5.8 install. That is a one-time, local-only fix - do
not commit the resulting .uproject change.
'@
}

# --- Summary ----------------------------------------------------------------
Write-Host ''
if ($warnings.Count -eq 0) {
    Write-Host 'Setup complete. Open ProjectFiles\ProjectFiles.uproject to start.' -ForegroundColor Green
} else {
    Write-Host "Setup finished with $($warnings.Count) warning(s) - see above." -ForegroundColor Yellow
}
Write-Host 'First editor launch compiles shaders and will take a while. See CONTRIBUTING.md.'
Write-Host ''
