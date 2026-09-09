#!/usr/bin/env bash
# First-time setup for a fresh clone of The Throes of Man (macOS / Linux).
# Windows developers should use Setup.ps1 instead.
#
# Safe to re-run at any time.
#
#   ./setup.sh

set -u
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
warnings=0

step() { printf '\n\033[36m[%s] %s\033[0m\n' "$1" "$2"; }
ok()   { printf '    OK   %s\n' "$1"; }
warn() { printf '    \033[33mWARN %s\033[0m\n' "$1"; warnings=$((warnings + 1)); }
die()  { printf '\n\033[31mFAILED: %s\033[0m\n' "$1"; exit 1; }

echo "The Throes of Man - clone setup"
echo "Repository: $repo"

# --- 1. Prerequisites -------------------------------------------------------
step 1 'Checking prerequisites'
command -v git >/dev/null 2>&1 || die 'git not found. Install it and re-run.'
ok "$(git --version)"

if ! command -v git-lfs >/dev/null 2>&1; then
    die 'git-lfs not found. Every binary asset (.uasset, .umap, textures, audio)
is stored in Git LFS - without it you get 133-byte text pointers instead of
assets and the editor will not open the project.

Install:  brew install git-lfs   |   apt install git-lfs   |   https://git-lfs.com
Then re-run this script.'
fi
ok "$(git lfs version)"

# --- 2. LFS filters ---------------------------------------------------------
step 2 'Installing Git LFS filters (global)'
git lfs install >/dev/null || die 'git lfs install failed.'
ok 'clean/smudge filters registered'

# --- 3. Hooks path ----------------------------------------------------------
# core.hooksPath cannot be set by the repository itself, so it must be set per
# clone. It points at .githooks/, which holds the pre-commit guard against
# committing raw binaries plus the LFS hooks.
step 3 'Pointing Git at the tracked hooks directory'
git -C "$repo" config core.hooksPath .githooks
chmod +x "$repo"/.githooks/* 2>/dev/null
ok "core.hooksPath = $(git -C "$repo" config core.hooksPath)"

# --- 4. Fetch asset binaries ------------------------------------------------
step 4 'Downloading asset binaries from LFS (this can take a few minutes)'
git -C "$repo" lfs pull || die 'git lfs pull failed. Check your network and GitHub access.'
ok 'LFS objects pulled'

# --- 5. Verify assets are real files, not pointers --------------------------
step 5 'Verifying assets resolved correctly'
probe="$repo/ProjectFiles/Content/Characters/Mannequins/Meshes/SKM_Manny_Simple.uasset"
if [ -f "$probe" ]; then
    size=$(wc -c < "$probe" | tr -d ' ')
    if [ "$size" -lt 1024 ]; then
        die "$probe is only $size bytes - it is still an LFS pointer. Run 'git lfs pull' manually and check for errors."
    fi
    ok "sample asset is $((size / 1048576)) MB (real binary)"
else
    warn "Probe asset not found - skipped verification."
fi

# --- Summary ----------------------------------------------------------------
echo
if [ "$warnings" -eq 0 ]; then
    printf '\033[32mSetup complete. Open ProjectFiles/ProjectFiles.uproject to start.\033[0m\n'
else
    printf '\033[33mSetup finished with %s warning(s) - see above.\033[0m\n' "$warnings"
fi
echo 'Note: this project targets Windows as its primary platform (SPEC.md). macOS/Linux'
echo 'editor use is untested. First editor launch compiles shaders and will take a while.'
echo
