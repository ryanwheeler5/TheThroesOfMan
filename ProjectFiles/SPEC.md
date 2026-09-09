# SPEC.md — First-Person Game (Unreal Engine 5.8)

> **Purpose of this document:** This is a machine-readable specification intended to be consumed by LLM coding agents to scaffold, implement, and extend a first-person game project in Unreal Engine 5.8. It defines architecture, conventions, and tech stack at a general level. Treat every section as authoritative unless overridden by a more specific spec file (e.g. `SPEC.combat.md`, `SPEC.ai.md`) added later. When information is ambiguous, prefer Unreal Engine 5.8 defaults and idiomatic C++/Blueprint patterns.

---

## 1. Project Metadata

| Key | Value |
|---|---|
| Engine | Unreal Engine 5.8 |
| Genre | First-person (FPS-style control scheme; genre-agnostic beyond that) |
| Primary Language | Blueprint (content-layer logic, designer-tunable behavior, UI glue) |
| Secondary Language | C++ (gameplay framework, performance-critical systems) |
| Target Platforms | PC (Windows) primary; consider console/portability constraints when relevant |
| Rendering Path | Lumen + Nanite (UE5 default pipeline) unless a specific system opts out |
| Project Status | Early scaffolding — this spec describes intended shape, not final content |

**Agent instruction:** When generating code or content, assume this metadata unless the user's prompt explicitly overrides it.

---

## 2. High-Level Architecture

The project follows Unreal's standard **Gameplay Framework** separation of concerns. Agents should map new features onto these existing framework classes rather than inventing parallel systems.

```
GameInstance
 └── GameMode (server-authoritative rules, spawning, win/lose state)
      └── GameState (replicated match/session state)
      └── PlayerController (input ownership, camera, UI ownership)
           └── PlayerState (replicated per-player data: score, identity)
           └── Pawn / Character (ACharacter subclass — the first-person body)
                └── Camera Component (first-person view)
                └── Mesh Components (first-person arms mesh + third-person body mesh)
                └── Movement Component (CharacterMovementComponent, extended as needed)
                └── ActorComponents (modular gameplay systems — see §4)
```

**Core principles agents must follow:**
1. **Composition over inheritance for gameplay features.** New abilities/systems should be `UActorComponent` or `UGameplayAbility`-style modules attached to the Pawn, not new Pawn subclasses per feature.
2. **C++ defines structure; Blueprint tunes values.** Base classes, interfaces, and performance-sensitive logic live in C++. Designer-facing subclasses (`BP_PlayerCharacter`, `BP_WeaponRifle`, etc.) live in Blueprint and expose `UPROPERTY(EditAnywhere, BlueprintReadWrite)` tunables.
3. **Data-driven content.** Use `DataAssets` / `DataTables` for weapon stats, enemy stats, item definitions, etc., rather than hardcoding values in logic classes.
4. **Interfaces over hard casts.** Cross-system communication (e.g. "damageable," "interactable") should go through `UInterface`s, not `Cast<>` chains to concrete classes.
5. **Single source of truth for state.** Replicated state lives on the Character/PlayerState/GameState per Unreal's authority model — do not duplicate state across systems.

---

## 3. Tech Stack

| Layer | Technology |
|---|---|
| Engine | Unreal Engine 5.8 |
| Language (core) | C++20 (per UE5.8 toolchain defaults) |
| Language (content) | Blueprint Visual Scripting |
| Input | Enhanced Input System (Input Actions + Input Mapping Contexts — **not** legacy Action/Axis mappings) |
| Rendering | Lumen (GI/reflections), Nanite (geometry), World Partition (level streaming, if open-world scale) |
| Animation | Control Rig / Animation Blueprints; first-person arms as a separate skeletal mesh from third-person body |
| AI (if applicable) | Behavior Trees + Blackboards, EQS (Environment Query System) for spatial queries |
| Networking | Unreal's built-in replication model (Actor/Component replication, RPCs); design for dedicated server compatibility even in single-player-first builds |
| UI | UMG (Unreal Motion Graphics) |
| Audio | MetaSounds |
| Physics | Chaos Physics (UE5 default) |
| Build/Source Control | Standard `.uproject` + `Source/` C++ modules; assume Perforce or Git with Git LFS for binary assets unless told otherwise |
| Config | `DefaultEngine.ini`, `DefaultInput.ini`, `DefaultGame.ini` — respect existing config-driven values over hardcoding |

**Agent instruction:** Do not introduce third-party plugins, middleware, or external engines unless explicitly requested. Prefer built-in UE5.8 systems (e.g. Enhanced Input over raw input, MetaSounds over legacy Sound Cues) since they are the modern default.

---

## 4. Core Gameplay Systems (Modular Components)

Each system below should be implemented as an isolated, attachable module (typically a `UActorComponent` or subsystem) with a clear public interface. Agents implementing one system should not need to modify unrelated systems.

- **Movement** — walking, sprinting, crouching, jumping; extends `UCharacterMovementComponent`.
- **Camera / View** — first-person camera component, head-bob, FOV/recoil kick, view-punch effects.
- **Input Handling** — Enhanced Input Actions mapped to gameplay intents (Move, Look, Jump, Interact, PrimaryAction, etc.), decoupled from specific device bindings.
- **Health / Damage** — a `Damageable` interface implemented by any actor that can take damage; a `HealthComponent` for state tracking.
- **Inventory / Equipment** — data-driven item/weapon definitions; an `InventoryComponent` managing owned items; an `EquipmentComponent` managing the currently active/held item.
- **Weapons / Abilities** (if genre-relevant) — base `AWeaponBase` / ability class with designer-overridable Blueprint subclasses per weapon or ability.
- **Interaction** — a generic `Interactable` interface (line-trace or overlap-based) for doors, pickups, switches, NPCs.
- **UI/HUD** — UMG widgets bound to component state via delegates/events, not polling.
- **Save/Load** (if applicable) — `USaveGame` subclasses per save domain (player progress, world state).
- **Audio/VFX feedback** — triggered via gameplay events, not embedded directly in core logic (keep presentation decoupled from simulation).

**Agent instruction:** When asked to add a new gameplay feature, first check whether it fits as a new component/interface implementation within this list before creating new top-level systems.

---

## 5. Naming & Project Conventions

Agents should follow Epic's standard C++ and Blueprint conventions unless the project's existing codebase indicates otherwise:

- **C++ classes:** `A` prefix for Actors (`APlayerCharacter`), `U` for UObject/Components (`UHealthComponent`), `F` for structs (`FWeaponStats`), `I` for interfaces (`IDamageable`), `E` for enums (`EWeaponState`).
- **Blueprints:** `BP_` prefix for Blueprint classes (`BP_PlayerCharacter`), `WBP_` for Widget Blueprints (`WBP_HUD`), `DA_` for Data Assets, `DT_` for Data Tables.
- **Folder structure:** Mirror `Content/` organization by system/domain (e.g. `Content/Characters/Player/`, `Content/Weapons/Rifle/`), not by asset type.
- **C++ module structure:** Gameplay code under `Source/<ProjectName>/Public|Private`, subdivided by system (e.g. `Public/Weapons/`, `Public/Movement/`).

---

## 6. Non-Goals / Constraints for Agents

- Do not hardcode gameplay-tunable values (damage, speed, cooldowns) directly in C++ — expose as `UPROPERTY` for Blueprint/designer tuning or move to a DataAsset/DataTable.
- Do not assume single-player-only unless told; structure replication-aware code (server RPCs, `IsLocallyControlled()` checks) even if multiplayer isn't active yet.
- Do not use deprecated UE4-era input (legacy Action/Axis Mappings) — Enhanced Input only.
- Do not reproduce or reference copyrighted third-party game assets, IP, or branded content.
- This spec is intentionally non-specific on content (no fixed weapon roster, level list, or narrative). Treat those as open decisions unless a more detailed spec supersedes this one.

---

## 7. Extension Points for Future Sub-Specs

This document is expected to be supplemented by more detailed specs as the project grows. Suggested future files, to be authored in the same LLM-optimized style:

- `SPEC.movement.md` — detailed traversal mechanics
- `SPEC.combat.md` — weapons, damage, TTK design
- `SPEC.ai.md` — enemy behavior trees, perception
- `SPEC.ui.md` — HUD/menu flow and widget architecture
- `SPEC.multiplayer.md` — replication and netcode specifics
- `SPEC.art.md` — art direction and asset pipeline standards

**Agent instruction:** If a task requires detail not covered here and no relevant sub-spec exists, ask for clarification or propose reasonable defaults consistent with §2–§6 above rather than inventing conflicting architecture.
