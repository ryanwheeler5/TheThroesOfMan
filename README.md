# TheThroesOfMan

Game project of TSG Ventures LLC. A first-person game built in **Unreal Engine 5.8**.

## Getting started

```bash
git clone https://github.com/ryanwheeler5/TheThroesOfMan.git
cd TheThroesOfMan
powershell -ExecutionPolicy Bypass -File Setup.ps1   # Windows
./setup.sh                                           # macOS / Linux
```

Then open `ProjectFiles/ProjectFiles.uproject`.

**Install [Git LFS](https://git-lfs.com) before cloning** — every binary asset lives in LFS,
and without it you get text pointers instead of art. `Setup.ps1` checks for this and will
tell you if it is missing.

Full setup, asset workflow and conventions: **[CONTRIBUTING.md](CONTRIBUTING.md)**.

## How to make changes

1. `git checkout master` and `git pull` latest changes
2. Open a branch, name does not matter
3. `git push` to send changes to GitHub
4. Open a PR for review against master, requires one approval

Keep branches short-lived and rebase onto `master` often — Unreal assets are binary and
cannot be merged, so two people editing the same `.uasset` means one of them loses their
work. See [CONTRIBUTING.md §2](CONTRIBUTING.md#2-working-with-assets).

## Documentation

| File | Contents |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Setup, asset workflow, commit rules, MCP tooling |
| [ProjectFiles/SPEC.md](ProjectFiles/SPEC.md) | Architecture, tech stack and conventions |
| [ProjectFiles/PROJECT_STATE.md](ProjectFiles/PROJECT_STATE.md) | Current state vs spec, and the task list |
| [ProjectFiles/CLAUDE.md](ProjectFiles/CLAUDE.md) | Instructions for AI coding agents |
