**Architecture/Coupling Status Update**

**Recently addressed**

1. `Autoloads/Scripts/SaveManager.gd`  
Status: **Major schema risk addressed**.  
What changed: Save/load now uses a keyed payload schema (with format/schema metadata), plus legacy positional-save compatibility. Backup fallback and loaded-state normalization are centralized, reducing breakage from field reordering/type drift.  
Residual risk: Save ownership is still centralized in one manager and still coupled to `GameManager` facades.

2. `Autoloads/Scripts/SceneManager.gd` and `Autoloads/Scripts/AdManager.gd`  
Status: **Partially addressed**.  
What changed: Banner policy/visibility orchestration was moved out of `SceneManager` and consolidated in `AdManager`, with scene-change hooks and idempotent show/hide guards. `SceneManager` no longer directly toggles ad banners.  
Residual risk: Ad lifecycle and revive timing/state are still spread across managers and UI paths.

3. `MainScenes/Scripts/game_over_screen.gd` + `Autoloads/Scripts/GameManager.gd` revive flow  
Status: **Feature-level improvement landed**.  
What changed: Added crystal revive path (escalating costs, per-level limits) and free-ad revive gating.  
Residual risk: Revive policy/state is still coordinated through `GameManager` and `AdManager`, not yet isolated into a dedicated revive domain/service.

**High-risk files still unresolved**

1. `Autoloads/Scripts/GameManager.gd`  
Why risky: Still a high-fan-out orchestrator with mixed responsibilities (runtime state, persistence/config facades, ad/revive flow, scene flow, player/level coordination, signals).  
What other files they affect: `Autoloads/Scripts/SaveManager.gd`, `Autoloads/Scripts/SceneManager.gd`, `Autoloads/Scripts/AdManager.gd`, `Autoloads/Scripts/PlayerManager.gd`, `Autoloads/Scripts/LevelManager.gd`, `Ships/Scripts/Player.gd`, `Enemy/Scripts/Enemy.gd`, `MainScenes/Scripts/*.gd`.

2. `Autoloads/Scripts/ConfigLoader.gd`  
Why risky: Still a global data singleton with broad ripple impact; config ownership/validation and fallback behavior remain centralized and failure-prone.  
What other files they affect: `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/SaveManager.gd`, `Autoloads/Scripts/AdManager.gd`, `Autoloads/Scripts/PlayerManager.gd`, `Enemy/Scripts/Enemy.gd`, `MainScenes/Scripts/upgrade_menu.gd`.

3. `Autoloads/Scripts/SceneManager.gd`  
Why risky: Reduced ad coupling, but scene transition + loader + audio concerns are still concentrated with scene-path assumptions.  
What other files they affect: `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/AdManager.gd`, `Autoloads/Scripts/AudioManager.gd`, level/menu scenes.

4. `Autoloads/Scripts/AdManager.gd`  
Why risky: Improved banner policy boundaries, but ad lifecycle + revive state + UI/scene assumptions remain mixed and race-prone.  
What other files they affect: `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/SceneManager.gd`, `Autoloads/Scripts/PlayerManager.gd`, `MainScenes/Scripts/game_over_screen.gd`, `MainScenes/Scripts/pause_menu.gd`.

5. `Ships/Scripts/Player.gd`  
Why risky: Still very large and multi-responsibility (input, shooting, mode effects, persistence triggers, satellite orchestration, UI signaling).  
What other files they affect: `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/PlayerManager.gd`, `Autoloads/Scripts/LevelManager.gd`, `Autoloads/Scripts/BulletFactory.gd`, `Satellites/Scripts/*.gd`.

6. `Enemy/Scripts/Enemy.gd`  
Why risky: Still combines movement/firing/spawn/mode/lifecycle behavior in one class with dense coupling.  
What other files they affect: `Enemy Manager/Scripts/WaveManager.gd`, `Enemy Manager/Scripts/formation_enums.gd`, `Enemy Manager/Scripts/WaveConfig.gd`, `Autoloads/Scripts/GameManager.gd`, bullet/resource scenes.

7. `MainScenes/Scripts/upgrade_menu.gd`  
Why risky: Still a large UI-plus-domain script with heavy direct config/save interactions and concentrated transactional behavior.  
What other files they affect: `Autoloads/Scripts/GameManager.gd`, `Autoloads/Scripts/SaveManager.gd`, `Autoloads/Scripts/PlayerManager.gd`, `Autoloads/Scripts/AdManager.gd`, `Autoloads/Scripts/ConfigLoader.gd`.

8. `Autoloads/Scripts/BulletFactory.gd` and `Bullet/Scripts/BulletBase.gd`  
Why risky: Global pooling assumptions and shared bullet lifecycle contracts remain implicit and cross-cutting.  
What other files they affect: `Ships/Scripts/Player.gd`, `Enemy/Scripts/Enemy.gd`, `Satellites/Scripts/*.gd`, bullet scenes.

**Suggested order to fix next (no code)**

1. `Ships/Scripts/Player.gd` and `Enemy/Scripts/Enemy.gd`  
2. `MainScenes/Scripts/upgrade_menu.gd`  
3. `Autoloads/Scripts/BulletFactory.gd` and `Bullet/Scripts/BulletBase.gd`  
4. `Autoloads/Scripts/ConfigLoader.gd` ownership/validation hardening  
5. `Autoloads/Scripts/GameManager.gd` residual god-object surface reduction  
6. `Autoloads/Scripts/SceneManager.gd` + `Autoloads/Scripts/AdManager.gd` race/lifecycle cleanup pass
