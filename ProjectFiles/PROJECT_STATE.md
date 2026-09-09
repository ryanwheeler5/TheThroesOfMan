# PROJECT_STATE.md — Current State vs SPEC.md

_Snapshot: 2026-09-09 · Branch `feature/config` · Engine 5.8.2 (`++UE5+Release-5.8-CL-56702186`)_

## 1. Summary

The project is an **unmodified Unreal 5.8 First Person Blueprint template**, renamed `ProjectFiles`, with the weapon/variant content stripped out. It runs and is playable (move/look/jump in a prototype blockout level), but **none of the architecture described in SPEC.md exists yet**: there is no C++ module, no gameplay components, no interfaces, no data assets, and no game-specific identity.

Gap vs spec: SPEC §1–§3 (metadata/stack) is largely satisfied by template defaults; SPEC §2 (architecture), §4 (systems) and §5 (conventions) are essentially unstarted.

## 2. What Exists

### Project shell

| Item | State |
|---|---|
| `ProjectFiles.uproject` | Blueprint-only — **no `Modules` section, no `Source/`** |
| `EngineAssociation` | `"5.8"` (fixed 2026-09-09 — was a machine-local GUID that only resolved on one developer's registry) |
| Project name | `First Person BP Game Template` (DefaultGame.ini) — not "The Throes of Man" |
| Plugins enabled | `ModelingToolsEditorMode` (editor), `GameplayStateTree`, `ModelContextProtocol`, `Terminal`, `EditorToolset` — all first-party; no third-party middleware |

### Content (248 tracked assets)

- **`Content/FirstPerson/Blueprints/`** — `BP_FirstPersonCharacter` (ACharacter: Capsule + CharacterMovement + `FirstPersonCamera` + Manny mesh with `ABP_Unarmed` + FP mesh with `ABP_FP_Copy`), `BP_FirstPersonGameMode` (GameModeBase, sets default pawn + PC), `BP_FirstPersonPlayerController` (adds `IMC_Default` / `IMC_MouseLook`, sets camera manager class), `BP_FirstPersonCameraManager`.
- **`Content/Input/`** — Enhanced Input only: `IMC_Default`, `IMC_MouseLook`, `IA_Move`, `IA_Look`, `IA_MouseLook`, `IA_Jump`, plus mobile touch assets (`BPI_TouchInterface`, `UI_TouchSimple`, `UI_Thumbstick`).
- **`Content/FirstPerson/Lvl_FirstPerson.umap`** — World Partition / One File Per Actor enabled (63 external actors); contents are prototype cubes, ramps and quarter-cylinders only.
- **`Content/Characters/Mannequins/`** — Manny/Quinn meshes, materials, control rigs, and a **full Rifle/Pistol/Unarmed animation set** (fire, reload, equip, ADS, hit-reacts, deaths). The animations exist but **nothing consumes them**: no weapon actor, no armed anim BP, no locomotion state machine using the pistol/rifle sets.
- **`Content/LevelPrototyping/Interactable/`** — `BP_DoorFrame`, `BP_JumpPad`, `BP_WobbleTarget` exist as assets but are **not placed in the level** and share no common interaction interface.

### Config

- Lumen (`r.DynamicGlobalIlluminationMethod=1`) + hardware ray tracing on, Nanite on, Substrate on, Virtual Shadow Maps on, static lighting off, MegaLights off — matches SPEC §1 rendering path.
- Enhanced Input is the default player input / input component class; only the engine's inherited legacy axis config remains.
- `GlobalDefaultGameMode` → `BP_FirstPersonGameMode`; `GameInstanceClass` → stock `Engine.GameInstance`.
- Collision profile `Projectile` + `ECC_GameTraceChannel1` already defined (leftover from the template's shooter variant).

### Repo hygiene

- `.gitignore` correctly excludes `Saved/`, `Intermediate/`, `DerivedDataCache/`, `Binaries/`, `Build/`.
- **Git LFS is now active** (fixed 2026-09-09). `.gitattributes` previously matched only `Content/FPWeapon/**`, a folder that does not exist, so all 248 assets were raw blobs — and commit `b8bdb7e` also carried a 127 MiB `CachedAssetRegistry` blob that GitHub would have rejected outright. Both offending commits were unpushed and have been rebuilt: 238 binaries now stage as LFS pointers and the engine-generated junk is gone from history.
- A `.githooks/pre-commit` hook (repo root) blocks commits that stage engine-generated junk, raw blobs matching an LFS rule, or >5 MiB files with no LFS rule. Enable per clone: `git config core.hooksPath .githooks`.
- `CLAUDE.md`, `SPEC.md` and `.claude/` are untracked.
- `.mcp.json` points at `unreal-mcp` on `http://127.0.0.1:8000/mcp`; the server is currently unreachable, and the editor log shows `LogModelContextProtocol: Error: Call to unknown method "server/discover"`.

## 3. What's Missing vs SPEC.md

| SPEC ref | Requirement | Status |
|---|---|---|
| §2, §5 | C++ layer defining base classes / interfaces (`Source/<Project>/Public\|Private`) | **Absent** — no C++ module at all |
| §2 | GameInstance / GameState / PlayerState subclasses | **Absent** (GameModeBase + PlayerController only) |
| §2.1 | Composition: gameplay features as `UActorComponent` | **Absent** — all logic sits in the character BP |
| §2.3 | Data-driven content (DataAssets / DataTables) | **Absent** — no `DA_` / `DT_` assets |
| §2.4 | `UInterface`s for cross-system communication | **Absent** — no Damageable / Interactable interface |
| §2.5, §6 | Replication-aware structure | **Absent** — single-player template logic, no authority checks |
| §4 | Movement: sprint, crouch | **Absent** (walk + jump only; no CMC subclass) |
| §4 | Camera: head-bob, FOV kick, view punch | **Absent** |
| §4 | Input intents: Interact, PrimaryAction, Sprint, Crouch | **Absent** (only Move / Look / MouseLook / Jump) |
| §4 | Health / Damage (`HealthComponent`, `IDamageable`) | **Absent** |
| §4 | Inventory / Equipment | **Absent** |
| §4 | Weapons / Abilities (`AWeaponBase`) | **Absent** — animations exist, systems do not |
| §4 | Interaction interface | **Absent** — 3 ad-hoc interactable BPs, no shared contract |
| §4 | UI / HUD (UMG, delegate-bound) | **Absent** — no `WBP_` widgets, no HUD class |
| §4 | Save/Load (`USaveGame`) | **Absent** |
| §4 | Audio (MetaSounds) / VFX feedback | **Absent** — no sound assets in the project |
| §3 | AI: Behavior Trees / Blackboard / EQS | **Absent** — no AI content, no enemies |
| §5 | Folder structure by domain (`Content/Characters/Player/`, `Content/Weapons/…`) | **Partial** — still template-shaped (`Content/FirstPerson/`) |
| §7 | Sub-specs (`SPEC.movement.md`, `SPEC.combat.md`, …) | **Not authored** |

## 4. TODOs

### P0 — Foundation (blocks everything else)

- [ ] **Add a C++ module.** Convert to a code project: `Source/<GameName>/{Public,Private}` + `.Build.cs` + `.Target.cs`, and register `Modules` in the `.uproject`. Without this, SPEC §2/§5 cannot be honored.
- [x] ~~**Fix Git LFS.**~~ Done 2026-09-09 — `.gitattributes` rewritten, unpushed history rebuilt so binaries are LFS pointers, `pre-commit` guard added.
- [ ] **Establish project identity.** Set `ProjectName` in `DefaultGame.ini`; decide the C++ module / game name and whether to rename the `ProjectFiles` uproject.
- [x] ~~**Pin the engine.**~~ Done 2026-09-09 — `EngineAssociation` is now `"5.8"`. Onboarding, asset workflow and MCP setup are documented in the repo-root `CONTRIBUTING.md`, automated where possible by `Setup.ps1` / `setup.sh`.
- [ ] Commit the staged foundation work (`CLAUDE.md`, `SPEC.md`, `PROJECT_STATE.md`, `.githooks/`, `.gitattributes`) — currently staged, not committed.

### P1 — Core framework (SPEC §2)

- [ ] C++ bases for GameMode / GameState / PlayerState / GameInstance; reparent the existing BPs onto them.
- [ ] `APlayerCharacter` C++ base (camera, FP/TP mesh split, Enhanced Input wiring, `IsLocallyControlled()`-aware), with `BP_PlayerCharacter` as the designer subclass.
- [ ] `IDamageable` and `IInteractable` interfaces in C++.
- [ ] `UHealthComponent` with replicated health + delegates.
- [ ] `UInteractionComponent` (camera line trace) driving `IInteractable`; retrofit `BP_DoorFrame` / `BP_JumpPad` / `BP_WobbleTarget` onto it.

### P2 — Gameplay systems (SPEC §4)

- [ ] Movement: CMC subclass or component adding sprint + crouch; add `IA_Sprint`, `IA_Crouch`, `IA_Interact`, `IA_PrimaryAction` and map them in `IMC_Default`.
- [ ] Camera feel: head-bob / FOV kick / view punch as a camera component.
- [ ] `UInventoryComponent` + `UEquipmentComponent` driven by `UPrimaryDataAsset` item definitions (`DA_`).
- [ ] `AWeaponBase` + `DA_WeaponDefinition` / `DT_WeaponStats`; wire the existing Rifle/Pistol anim sets into an armed anim BP with a locomotion state machine.
- [ ] HUD: HUD class + `WBP_HUD` bound to component delegates (not Tick polling).
- [ ] MetaSound assets for weapon / movement / interaction feedback, triggered by gameplay events.

### P3 — Content & polish

- [ ] Reorganize `Content/` by domain per SPEC §5 (`Content/Characters/Player/`, `Content/Weapons/`, `Content/UI/`, `Content/Levels/`); rename `Lvl_FirstPerson` to a real level.
- [ ] Decide on and remove the mobile/touch input assets if PC-only (`Content/Input/Touch/`).
- [ ] Verify `r.AntiAliasingMethod=0` in `DefaultEngine.ini` is intentional — UE5's default is TSR; the template's "Scalable" hardware target may have disabled AA.
- [ ] Author the sub-specs that gate detailed work: `SPEC.movement.md`, `SPEC.combat.md`, `SPEC.ui.md`, then `SPEC.ai.md` / `SPEC.multiplayer.md` / `SPEC.art.md`.
- [ ] Save/Load domains once there is progression state worth persisting.

### Open questions

1. Game name / module name — is "The Throes of Man" the shipping name, and should the `.uproject` be renamed off `ProjectFiles`?
2. Genre beyond first-person: does this game have weapons/combat at all, or is the pistol/rifle anim set dead weight to delete?
3. Multiplayer: design for dedicated-server compatibility now (SPEC §6 says yes), or single-player first?
4. Is GAS (`GameplayAbilities` plugin) in scope, or plain `UActorComponent` systems? SPEC §2.1 hints at "`UGameplayAbility`-style" without committing.
