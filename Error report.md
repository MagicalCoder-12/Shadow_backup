**Fix Progress Summary**

Tracked items in this report: **13**

- Completed: **5**
- Partial: **1**
- Remaining: **7**
- Effective completion (partial counted as 0.5): **42.3%**
- Remaining effort: **57.7%**

**Completed**

1. `Autoloads/Scripts/SaveManager.gd`  
Status: **Completed**  
Notes: Keyed payload save schema, legacy compatibility, backup fallback, and normalization were added.

2. `MainScenes/Scripts/game_over_screen.gd` + `Autoloads/Scripts/GameManager.gd` crystal revive flow  
Status: **Completed**  
Notes: Crystal revives added with per-level limits and escalating cost; ad revive remains optional.

3. `MainScenes/Scripts/game_over_screen.gd` message and resource display  
Status: **Completed**  
Notes: Message label is shown from start and updated by button interaction; `void_shards_display`, `crystals_display`, and `coins_display` now show current player resources.

4. Revive life count bug (`Levels/Scripts/Level.gd`, `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/PlayerManager.gd`)  
Status: **Completed**  
Notes: Revive now restores **1 life** consistently (no more 2-life revive).

5. `Autoloads/Scripts/GameManager.gd` revive limit reset integration  
Status: **Completed**  
Notes: Revive counters reset for new game/new level to prevent carry-over between levels.

**Partial**

1. `Autoloads/Scripts/SceneManager.gd` + `Autoloads/Scripts/AdManager.gd` ad orchestration  
Status: **Partial**  
Done: Banner visibility policy moved from scene manager into ad manager with guard rails.  
Remaining: Lifecycle/race cleanup and full revive-state ownership split are still needed.

**Remaining (High Priority)**

1. `Autoloads/Scripts/GameManager.gd`  
Why: Still a high-fan-out orchestrator with mixed responsibilities.

2. `Autoloads/Scripts/ConfigLoader.gd`  
Why: Global config ownership and validation/fallback behavior are still centralized and brittle.

3. `Autoloads/Scripts/SceneManager.gd`  
Why: Scene transition, loading, and audio concerns remain concentrated.

4. `Autoloads/Scripts/AdManager.gd`  
Why: Ad lifecycle, retry, and revive interactions still need a race-condition hardening pass.

5. `Ships/Scripts/Player.gd`  
Why: Script is still large and multi-responsibility.

6. `Enemy/Scripts/Enemy.gd`  
Why: Movement/firing/spawn/mode/lifecycle behavior remains tightly coupled.

7. `MainScenes/Scripts/upgrade_menu.gd` and `Autoloads/Scripts/BulletFactory.gd` + `Bullet/Scripts/BulletBase.gd`  
Why: Upgrade flow and bullet contracts still carry cross-cutting coupling risk.

**Suggested Next Fix Order**

1. `Autoloads/Scripts/AdManager.gd` race/lifecycle cleanup
2. `Ships/Scripts/Player.gd` + `Enemy/Scripts/Enemy.gd` decomposition
3. `MainScenes/Scripts/upgrade_menu.gd` separation of UI vs transaction logic
4. `Autoloads/Scripts/BulletFactory.gd` + `Bullet/Scripts/BulletBase.gd` contract hardening
5. `Autoloads/Scripts/GameManager.gd` surface reduction + responsibility split
