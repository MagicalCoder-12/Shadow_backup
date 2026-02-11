**Fix Progress Summary (Updated)**

Tracked remediation items in this report: **13**

- Completed: **9**
- Partial: **0**
- Remaining: **4**
- Completion (fully done items): **69.2%**
- Remaining effort: **30.8%**

**Completed**

1. `Autoloads/Scripts/Managers/SaveManager.gd`  
Status: **Completed**  
Notes: Keyed payload save schema, legacy compatibility, backup fallback, and normalization added.

2. `MainScenes/Scripts/game_over_screen.gd` + `Autoloads/Scripts/Core/GameManager.gd` crystal revive flow  
Status: **Completed**  
Notes: Crystal revives added with per-level limits and escalating cost; ad revive remains optional.

3. `MainScenes/Scripts/game_over_screen.gd` message and resource display  
Status: **Completed**  
Notes: Message label is visible from start and now updates by button interaction; resource labels now reflect current totals.

4. Revive life-count bug (`Levels/Scripts/Level.gd`, `Autoloads/Scripts/Core/GameManager.gd`, `Autoloads/Scripts/Managers/PlayerManager.gd`)  
Status: **Completed**  
Notes: Revive now restores exactly **1 life**.

5. `Autoloads/Scripts/Core/GameManager.gd` revive limit reset integration  
Status: **Completed**  
Notes: Revive counters reset at new run/new level boundaries.

6. `Autoloads/Scripts/Managers/AdManager.gd` race/lifecycle patch  
Status: **Completed**  
Notes: Request nonce tracking, stale-callback guards, dismiss-gated revive completion, timeout nonce checks, and `PROCESS_MODE_ALWAYS` handling are in place.

7. `Autoloads/Scripts/Managers/AdManager.gd` rewarded ad show-failure handling  
Status: **Completed**  
Notes: Added and connected `rewarded_ad_failed_to_show_full_screen_content` and `rewarded_interstitial_ad_failed_to_show_full_screen_content`, with unified fail-safe finalize logic.

8. `Autoloads/Scripts/Core/GameManager.gd` responsibility split (revive/currency/scene)  
Status: **Completed**  
Notes: Revive orchestration moved to `Autoloads/Scripts/Services/GameReviveService.gd`, scene routing moved to `Autoloads/Scripts/Services/GameSceneService.gd`, and currency/save helpers moved to `Autoloads/Scripts/Services/GameEconomyService.gd`.

9. Save batching/debounce strategy (`Autoloads/Scripts/Managers/SaveManager.gd`)  
Status: **Completed**  
Notes: Added debounced save scheduling with configurable delay, pending-save coalescing, and force-save path for shutdown and recovery.

---

**Deep Project Risk Audit**

Audit coverage:
- **102** GDScript files scanned.
- Largest scripts by size:
`MainScenes/Scripts/upgrade_menu.gd` (**1686**), `Ships/Scripts/Player.gd` (**1052**), `Enemy/Scripts/Enemy.gd` (**981**), `Autoloads/Scripts/Managers/AdManager.gd` (**760**), `Autoloads/Scripts/Core/GameManager.gd` (**690**), `Levels/Scripts/Level.gd` (**613**).
- Coupling indicators:
project-wide `GameManager.` references: **584**.
`MainScenes/Scripts/upgrade_menu.gd` refs: **139**.
`Ships/Scripts/Player.gd` refs: **139**.
- Async complexity indicators:
`await ...create_timer(...)` usages: **38**.
`save_progress(...)` call sites: **27**.

**High-Risk Elements (Prioritized)**

1. **Critical** - `Autoloads/Scripts/Core/GameManager.gd` remains a high-fan-out orchestrator.  
Evidence: 690-line script with global state, scene control, ads, currency, revive, save proxy, and shadow-mode orchestration.  
Risk: high regression blast radius and difficult bug isolation.

2. **High** - `MainScenes/Scripts/upgrade_menu.gd` is a monolith handling UI + economy + ad rewards + equip + save.  
Evidence: 1686 lines, 139 `GameManager` references, frequent direct save calls.  
Risk: UI fixes can break economy logic and vice versa.

3. **High** - `Ships/Scripts/Player.gd` is multi-responsibility (movement/combat/revive/satellites/modes/stats sync).  
Evidence: 1052 lines, 139 `GameManager` references.  
Risk: high fragility around revive/combat state transitions.

4. **High** - `Enemy/Scripts/Enemy.gd` bundles movement AI, attack patterns, shadow behavior, lifecycle, and rewards.  
Evidence: 981 lines with many mode-specific branches.  
Risk: balancing or AI fixes can cause hidden lifecycle regressions.

5. **High** - Scene-transition safety risk from direct `get_tree().current_scene.add_child(...)` usage in combat scripts.  
Evidence: direct add-child calls in enemy and boss scripts during runtime effects/spawns.  
Risk: null/current-scene churn during transitions causing intermittent runtime errors.

6. **Medium** - Save I/O is synchronous and called from many runtime paths.  
Evidence: 27 save call sites across gameplay/UI managers.  
Risk: unnecessary write pressure and potential save contention/stutter on low-end devices.

7. **Medium** - `Autoloads/Scripts/Managers/ConfigLoader.gd` still mixes loader + large embedded defaults.  
Evidence: large fallback payload definitions inline.  
Risk: config drift between JSON and hardcoded defaults; higher maintenance cost.

8. **Medium** - `Autoloads/Scripts/Managers/SceneManager.gd` mixes scene loading with audio bus policy.  
Evidence: scene transition logic plus bus mute/unmute orchestration in same unit.  
Risk: scene-flow changes can unintentionally affect audio state.

9. **Medium** - `MainScenes/Scripts/authentication.gd` is largely placeholder flow.  
Evidence: status-only handlers without actual auth service calls.  
Risk: false-ready auth UI path and inconsistent production behavior.

---

**Remaining High-Priority Fixes**

1. `MainScenes/Scripts/upgrade_menu.gd`  
Target: Separate transaction logic from UI rendering/state.
Progress: Upgrade/purchase payment flows and cost computation are delegated to `MainScenes/Scripts/Services/UpgradeTransactionService.gd`, ad request orchestration plus usage/reward messaging is delegated to `MainScenes/Scripts/Services/UpgradeAdService.gd`, selection/equip logic is delegated to `MainScenes/Scripts/Services/UpgradeSelectionService.gd`, and currency/texture refresh logic is delegated to `MainScenes/Scripts/Services/UpgradeUIRefreshService.gd`, while `upgrade_menu.gd` retains UI rendering/state updates.

2. `Ships/Scripts/Player.gd` + `Enemy/Scripts/Enemy.gd`  
Target: Extract revive/combat/mode/state-machine modules.

3. Scene-safe spawn/effect API for enemy/boss scripts  
Target: Replace raw `current_scene.add_child` with guarded spawn facade.

4. `Autoloads/Scripts/Managers/ConfigLoader.gd`  
Target: Move defaults into versioned data assets and add strict schema validation.
