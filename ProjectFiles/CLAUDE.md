#CLAUDE.md

We're building a game in Unreal Engine 5.8 described by @SPEC.MD. Read that file for general architectural tasks.

Keep your replies extremely concise and focus on conveying the key information. No unnecessary fluff, no long code snippets.

Whenever working with any third-party library or something similar, you MUST look up the official documentation to ensure that you're working with up-to-date information.
Use the DocsExplorer subagent for efficient documentation lookup.

## Before every commit

Unreal generates large binaries constantly. Raw binaries in Git history are permanent and GitHub hard-rejects any file over 100 MiB, so **check this before staging, not after committing**:

1. Run `git status --short` and confirm nothing from `Saved/`, `Intermediate/`, `DerivedDataCache/`, `Binaries/` or `Build/` is staged. If something is, add the pattern to `ProjectFiles/.gitignore` first.
2. If you are adding a **new binary file type** (audio, video, source art, a new asset extension), add its pattern to `ProjectFiles/.gitattributes` with `filter=lfs diff=lfs merge=lfs -text` **before** you `git add` it. The LFS filter runs at `git add` time — adding the rule afterwards does not retroactively convert what is already staged.
3. Verify with `git lfs status` that new binaries appear as LFS objects, not raw blobs.

The `.githooks/pre-commit` hook enforces all three and blocks the commit on violation. It is not a substitute for step 2 — the hook tells you a rule is missing, you still have to write it.

Never bypass with `--no-verify` without saying so explicitly and explaining why.

**One-time setup per clone:** `git config core.hooksPath .githooks`
