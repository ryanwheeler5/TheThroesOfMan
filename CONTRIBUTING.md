# Contributing to The Throes of Man

A first-person game built in **Unreal Engine 5.8**. Architecture and conventions live in
[`ProjectFiles/SPEC.md`](ProjectFiles/SPEC.md); current status and the task list live in
[`ProjectFiles/PROJECT_STATE.md`](ProjectFiles/PROJECT_STATE.md).

---

## 1. Getting set up

### Prerequisites

| Requirement | Notes |
|---|---|
| **Unreal Engine 5.8** | Exactly 5.8. Assets saved by a newer engine cannot be opened by an older one, so a teammate on 5.9 would lock everyone else out of anything they touch. |
| **Git** | Any recent version. |
| **Git LFS** | **Mandatory.** Every binary asset is stored in LFS. Without it you get 133-byte text pointers where assets should be and the project will not open. <https://git-lfs.com> |
| Visual Studio 2022 | Not needed yet — this is currently a Blueprint-only project. Once a C++ module lands (see PROJECT_STATE.md P0) you will need it with the **Game development with C++** workload. |

### Clone and run setup

```bash
git clone https://github.com/ryanwheeler5/TheThroesOfMan.git
cd TheThroesOfMan
```

Then, from the repository root:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File Setup.ps1
```

```bash
# macOS / Linux
./setup.sh
```

Open `ProjectFiles/ProjectFiles.uproject`. The first launch compiles shaders and will
take a long while — this is normal and only happens once (see [Shared DDC](#shared-ddc)
for how a team avoids paying that cost repeatedly).

### What the setup script does, and why it can't be automatic

Git deliberately does not let a repository configure the machine that clones it — otherwise
cloning a repo would be arbitrary code execution. Two settings therefore have to be applied
per clone, which is the entire reason this script exists:

1. **`git lfs install`** — registers the LFS clean/smudge filters in your global Git config,
   so binary assets are stored as pointers on commit and restored to real files on checkout.
2. **`git config core.hooksPath .githooks`** — points Git at this repo's tracked hooks
   directory, which holds both the LFS hooks and the `pre-commit` guard described below.

The script also pulls LFS objects, verifies a known asset resolved to a real binary rather
than a pointer, and checks that Unreal Engine 5.8 is discoverable. It is safe to re-run.

### Editor plugins

**Nothing to install.** All five plugins this project enables ship with UE 5.8 and are
resolved from the engine install, so they come up automatically when you open the project:

| Plugin | Engine location | Purpose |
|---|---|---|
| `ModelingToolsEditorMode` | Editor | In-editor mesh modeling (editor-only) |
| `GameplayStateTree` | Runtime | State Tree assets for gameplay/AI logic |
| `ModelContextProtocol` | **Experimental** | Exposes the editor to MCP clients — see §5 |
| `Terminal` | **Experimental** | Terminal panel inside the editor |
| `EditorToolset` | **Experimental** | Editor tooling framework |

Three are flagged **Experimental** by Epic: their APIs can change or be removed between
engine releases without deprecation. Don't build anything load-bearing on them.

There is no `ProjectFiles/Plugins/` directory and no marketplace dependencies. If you add a
plugin, say so in your PR — it becomes a setup step for everyone.

---

## 2. Working with assets

This is the part that differs most from a normal software repo. `.uasset` and `.umap` files
are **binary and cannot be merged**. If two people change the same asset on different
branches, resolving the "conflict" means picking one file and discarding the other person's
work entirely. Git cannot help you. Everything below exists to stop that from happening.

### Before you touch an asset

**Tell people what you're working on.** This sounds soft, but it is the primary defence.
A message in chat costs seconds; a lost afternoon of level work does not.

### One File Per Actor — already enabled

`Lvl_FirstPerson` uses World Partition, which enables One File Per Actor automatically. Each
actor is saved to its own file under `Content/__ExternalActors__/` rather than everyone
fighting over a single monolithic `.umap`. Per Epic's docs this is what makes concurrent
level editing viable at all.

**Keep World Partition on for every real level.** If you ever create a non-partitioned map,
enable One File Per Actor manually in World Settings.

### Developer folders

Use `ProjectFiles/Content/Developers/<yourname>/` for experiments and work-in-progress.
Content there is excluded from cooked builds and nobody else's work can depend on it, so you
can break things freely.

### Branch discipline

Because binary conflicts can only be resolved by discarding someone's work, the strategy is
to never let branches diverge far:

- Small, short-lived branches off `master`.
- Rebase onto `master` daily.
- Merge PRs promptly rather than parking them for a week.

### File locking (not yet enabled)

Git LFS supports exclusive locks via the `lockable` attribute in `.gitattributes`. Marked
files become read-only on disk until you run `git lfs lock <path>`, which makes accidental
concurrent edits structurally impossible rather than merely discouraged:

```bash
git lfs lock ProjectFiles/Content/.../Lvl_Foo.umap   # claim it
git lfs locks                                        # see who holds what
git lfs unlock ProjectFiles/Content/.../Lvl_Foo.umap # release
```

We have **not** turned this on yet — it adds real friction, and it is only worth it once more
than one person is regularly editing the same assets. When we do, `*.umap` is the first
candidate. GitHub's LFS locking API is not covered in their official REST documentation, so
test a lock/unlock round-trip before the team relies on it.

### LFS quota

GitHub Free/Pro includes **10 GiB of LFS storage and 10 GiB of bandwidth per month**. The
repository currently uses ~130 MB. The thing that catches game teams out is that **LFS keeps
every version of every file forever** — one 20 MB texture revised fifty times consumes 1 GB of
quota. Don't commit iterative saves of large assets; squash the experimentation into your
developer folder and commit the result.

---

## 3. Before every commit

Unreal continuously generates large binaries, and anything committed to Git history is
permanent. GitHub also hard-rejects any single file over 100 MiB — this repository already
had one 127 MiB engine cache blob committed and removed before it was ever pushed.

1. Run `git status --short`. Confirm nothing from `Saved/`, `Intermediate/`,
   `DerivedDataCache/`, `Binaries/` or `Build/` is staged. If it is, add the pattern to
   `ProjectFiles/.gitignore` first.
2. **Adding a new binary file type?** Add its pattern to `ProjectFiles/.gitattributes` with
   `filter=lfs diff=lfs merge=lfs -text` **before** you `git add` it. The LFS filter runs at
   `git add` time — adding the rule afterwards does not retroactively convert anything
   already staged.
3. Verify with `git lfs status` that new binaries appear as LFS objects, not raw blobs.

`.githooks/pre-commit` enforces all three and blocks the commit with a specific fix on
violation. It is not a substitute for step 2 — it tells you a rule is missing; you still have
to write it.

Do not use `git commit --no-verify` without saying so explicitly in the PR and explaining why.

---

## 4. Shared DDC

The Derived Data Cache holds compiled shaders and cooked asset data. By default it is local,
so **every developer recompiles every shader from scratch** on their first open — hours of
work, repeated per person, for identical output.

UE 5.4+ solves this with a **Zen Storage Server** on the LAN or VPN, configured through a
`[StorageServers]` section in `DefaultEngine.ini`:

```ini
[StorageServers]
Shared=(Host="http://<host>:8558", Namespace="throesofman.ddc", EnvHostOverride=UE-ZenSharedDataCacheHost, ...)
```

We have **not** set one up. It is the highest-value infrastructure investment once there is
more than one person on the project — worth doing before the third developer joins. Epic's
guide: [Set Up Zen Storage Server as Shared DDC](https://dev.epicgames.com/documentation/en-us/unreal-engine/set-up-zen-storage-server-as-shared-ddc-for-unreal-engine).
Note that Zen is unauthenticated and intended for trusted networks only.

---

## 5. MCP / AI tooling (optional)

Entirely optional — skip this section if you don't use an AI coding assistant. Nothing in
the build or the game depends on it.

### How it fits together

The `ModelContextProtocol` plugin makes **the Unreal Editor itself an MCP server**. It embeds
an HTTP server in the editor process and exposes engine operations — spawning actors,
configuring lighting, creating material instances, inspecting Slate widgets, running
automation tests — as tools that an external MCP client can call. The client connects *to the
running editor*; there is no separate server process to install.

`ProjectFiles/.mcp.json` is already committed and points at the default endpoint:

```json
{ "mcpServers": { "unreal-mcp": { "type": "http", "url": "http://127.0.0.1:8000/mcp" } } }
```

That file was generated by the engine. You can regenerate it for your own client from the
editor console:

```
ModelContextProtocol.GenerateClientConfig ClaudeCode
```

Supported client types are `ClaudeCode`, `Cursor`, `VSCode`, `Gemini`, `Codex`, and `All`.

### Turning it on

1. **Edit > Plugins** — confirm **Unreal MCP** and **All Toolsets** are enabled. Both are
   already on in the `.uproject`, so this should be true on a fresh clone. Toolset Registry
   comes in automatically as a dependency.
2. **Edit > Editor Preferences > General > Model Context Protocol** — enable
   **Auto Start Server** so it comes up with the editor. Port (`8000`) and URL path (`/mcp`)
   are configurable here if something else on your machine already owns that port; change
   `.mcp.json` to match if you do.
3. **The editor must be running** for the MCP server to exist. A client started against a
   closed editor simply fails to connect — that is expected, not a broken setup.
4. Start your AI client from the directory containing `.mcp.json` so it picks up the config.

For Claude Code specifically, per-machine MCP preferences live in
`ProjectFiles/.claude/settings.local.json`, which is gitignored — your local choices there
won't collide with anyone else's.

### Caveats

The plugin is **Experimental**: incomplete features, APIs subject to change without
deprecation, **no authentication layer**, and localhost-only by design. Don't expose the port
beyond your own machine.

You will also see `LogModelContextProtocol: Error: Call to unknown method "server/discover"`
in the editor log. It is benign — the plugin doesn't implement that discovery method yet — and
it does not stop the tools from working.

---

## 6. A note on Git vs Perforce

Epic officially recommends **Perforce or SVN** for Unreal projects — they are natively
integrated into the editor, and the editor's whole checkout/lock workflow is modelled on
Perforce. Git is not listed as a primary supported option, precisely because of the binary
merge problem described above.

Git + LFS is the right call while the team is small, and it is what we use. If more than
about five people are regularly touching art at the same time, expect this to become the
bottleneck, and expect the migration conversation.

---

## 7. Conventions

See [`ProjectFiles/SPEC.md`](ProjectFiles/SPEC.md) §5 for the full set. In brief:

- **C++:** `A` for Actors, `U` for UObject/Components, `F` for structs, `I` for interfaces,
  `E` for enums. Gameplay code under `Source/<Project>/Public|Private`, subdivided by system.
- **Blueprints:** `BP_` classes, `WBP_` widget blueprints, `DA_` data assets, `DT_` data tables.
- **Content folders:** organised by system/domain (`Content/Characters/Player/`,
  `Content/Weapons/Rifle/`), never by asset type.
- **C++ defines structure, Blueprint tunes values.** No hardcoded gameplay numbers in C++ —
  expose them as `UPROPERTY` or move them to a DataAsset/DataTable.
- **Enhanced Input only.** Legacy Action/Axis mappings are not to be used.
