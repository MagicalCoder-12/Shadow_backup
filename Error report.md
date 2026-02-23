# Deep Scan Error Report

Generated: **2026-02-19 08:43:46 UTC**
Scope: static scan of first-party gameplay code and scenes (`Autoloads`, `Bosses`, `Enemy`, `Enemy Manager`, `Levels`, `MainScenes`, `Ships`, `Spawner`, `Satellites`, `Bullet`).
Method: code pattern scan (`rg/find/wc`) and hotspot review by size, coupling, scene mutation, persistence pressure, async/signal complexity.

## 1. Scan Summary

- GDScript files scanned: **126**
- Scene files (`.tscn`) scanned: **106**
- First-party GDScript LOC: **18,228**
- `GameManager.` references: **417**
- `get_tree().current_scene` references: **61**
- Raw `call_deferred("add_child", ...)` calls: **43**
- `SceneSpawnService.spawn_child(...)` calls: **26**
- Save trigger callsites (`save_progress/request_save`): **37**
- Async timer usages (`create_timer` patterns): **51**
- Signal connection calls (`connect(...)`): **181**

## 2. Largest Code Hotspots

Top first-party scripts by length:

1. `MainScenes/Scripts/upgrade_menu.gd` - **1416**
2. `Bosses/Scripts/boss_1.gd` - **987**
3. `Enemy Manager/Scripts/formation_manager.gd` - **909**
4. `Bosses/Scripts/Boss3.gd` - **907**
5. `Enemy Manager/Scripts/wave_manager.gd` - **828**
6. `Autoloads/Scripts/Managers/AdManager.gd` - **811**
7. `Bosses/Scripts/Boss2.gd` - **715**
8. `Autoloads/Scripts/Core/GameManager.gd` - **614**
9. `Levels/Scripts/Level.gd` - **613**
10. `Ships/Scripts/Player.gd` - **612**

## 3. High-Risk Findings

### A. `upgrade_menu.gd` remains a high-complexity UI/economy orchestrator
- Severity: **High**
- Evidence: `MainScenes/Scripts/upgrade_menu.gd` is 1416 lines and has the highest `GameManager` coupling count.
- Risk: UI changes can still regress transaction/equip/save behavior in one edit path.
- Status: **Partially improved** (services exist), but root script still carries heavy orchestration.

### B. Boss scripts are still monolithic combat state machines
- Severity: **High**
- Evidence: `Bosses/Scripts/boss_1.gd` (987), `Bosses/Scripts/Boss3.gd` (907), `Bosses/Scripts/Boss2.gd` (715).
- Risk: pattern tuning and bug fixes have high regression blast radius.

### C. Enemy modularization is improved in base class, but subclass debt remains
- Severity: **High**
- Evidence:
  - Base enemy services extracted:
    - `Enemy/Scripts/Services/EnemyMovementService.gd`
    - `Enemy/Scripts/Services/EnemyCombatService.gd`
    - `Enemy/Scripts/Services/EnemyLifecycleService.gd`
  - Still large subclass scripts:
    - `Enemy/Scripts/SlowShooter.gd` (481)
    - `Enemy/Scripts/minion.gd` (467)
    - `Enemy/Scripts/FastEnemy.gd` (273)
- Risk: subclass overrides can bypass or drift from base service contracts.

### D. Scene-tree mutation is not yet fully centralized
- Severity: **High**
- Evidence:
  - Raw `current_scene.add_child(...)` still present in:
    - `Satellites/Scripts/satellite.gd:164`
    - `Satellites/Scripts/satellite.gd:167`
    - `Autoloads/Scripts/Managers/LevelManager.gd:135`
  - Raw `call_deferred("add_child", ...)` remains widespread in boss flows.
- Risk: transition timing/null parent race conditions during scene changes.

### E. Global coupling through `GameManager` is still high
- Severity: **Medium-High**
- Evidence: **417** direct references.
- Highest concentration:
  - `MainScenes/Scripts/upgrade_menu.gd` (**74**)
  - `Ships/Scripts/Player.gd` (**62**)
  - `Levels/Scripts/Level.gd` (**60**)
- Risk: hidden side effects and difficult unit-level isolation.

### F. Persistence calls remain frequent from gameplay/UI flows
- Severity: **Medium**
- Evidence: **37** save trigger callsites, including frequent upgrade-level paths.
- Risk: avoidable write pressure and state contention if events burst.
- Note: debounce exists in SaveManager; callsite count is still worth reducing.

### G. Signal lifecycle complexity is high
- Severity: **Medium**
- Evidence: **181** `connect(...)` calls in first-party scripts.
- Highest connect-heavy files:
  - `Enemy Manager/Scripts/wave_manager.gd` (17)
  - `Autoloads/Scripts/Managers/AdManager.gd` (17)
  - `Levels/Scripts/Level.gd` (15)
- Risk: duplicate connections and disconnect ordering issues in long sessions.

### H. Very large text scenes increase edit/load overhead
- Severity: **Medium**
- Evidence:
  - `MainScenes/pause_menu.tscn` ~17.22 MB
  - `MainScenes/game_over_screen.tscn` ~17.20 MB
  - `MainScenes/upgrade_menu.tscn` ~6.54 MB
- Risk: slower editor saves, merge churn, and runtime parsing overhead.

## 4. Recently Resolved Warnings

- Enum cast warning fixed:
  - `Enemy/Scripts/Enemy.gd:322` now casts int to enum (`as AttackPattern`).
- Focus warning fixed:
  - `Levels/Scripts/level_button.gd` no longer focuses non-focusable root control.
  - `MainScenes/Scripts/difficulty_selection.gd` now exposes `focus_default_control()`.

## 5. Current Architecture Status

### Completed/Stable
- Save schema + debounce (`SaveManager`) is in place.
- AdManager show/load failure paths are guarded.
- Player service extraction is in place.
- Enemy base extraction is in place (movement/combat/lifecycle services).

### Remaining Structural Work
- Subclass enemy modularization (`SlowShooter`, `FastEnemy`, `BossMinion`).
- Boss behavior extraction into pattern/state services.
- Full scene-spawn unification via `SceneSpawnService`.
- Further reduction of `GameManager` touchpoints from UI/combat scripts.

## 6. Priority Backlog (Recommended)

### P0 (Do next)
1. Replace remaining direct `current_scene.add_child` calls:
   - `Satellites/Scripts/satellite.gd`
   - `Autoloads/Scripts/Managers/LevelManager.gd`
2. Standardize boss/minion spawn/effect paths onto `SceneSpawnService`.

### P1
1. Extract `SlowShooter` into services:
   - targeting/aim
   - charge/defensive states
   - special projectile behavior
2. Extract `FastEnemy` rapid-fire/dive behavior into services.
3. Extract `BossMinion` swarm/orbit/kamikaze logic into services.

### P2
1. Split `upgrade_menu.gd` orchestration further (UI state controller vs domain facade).
2. Convert very large text scenes to binary `.scn` or externalized resources where practical.
3. Add signal connection audits in wave/boss lifecycle paths (connect once + explicit disconnect contracts).

## 7. Risk Snapshot

- Critical blockers found: **0** (static scan only)
- High-risk items open: **4**
- Medium-risk items open: **4**
- Trend: **Improving**, but complexity remains concentrated in upgrade, boss, and enemy-subclass layers.

