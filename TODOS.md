# TODOS

Deferred items from `/plan-eng-review` of `pr-7-conflict-fix` (2026-05-10).
Each entry: **What / Why / Pros / Cons / Context / Depends on**.

---

## Persistence: ProfileService migration

- **What:** Replace per-service load/save scaffolding in `CurrencyService`, `ShopService`, `DailyQuestService` with [ProfileService](https://madstudioroblox.github.io/ProfileService/) session-locking persistence.
- **Why:** PR #7 added a load-success flag (Issue 1 fix) which prevents "load fails → save overwrites real data" data loss. ProfileService is the industry-standard answer to that whole class of problems and adds session locking (prevents the same player loaded on two servers from racing saves).
- **Pros:** Battle-tested by hundreds of Roblox games; correct session locking; built-in retry; cleaner API.
- **Cons:** ~2-3 days work to migrate all three services; need to verify behavior bit-exact against current shipped saves; vendor library adds dependency surface.
- **Context:** Currently each service uses raw `DataStoreService:GetDataStore` + manual pcall. PR #7 keeps this pattern but adds `Loaded[player]=true` guard before save.
- **Depends on:** Nothing. Best done as a focused PR after #7 lands.

## Anti-cheat: full server-authoritative FireWeapon origin

- **What:** Stop trusting client-provided `origin` in `MatchManager.lua:445`; compute server-side from `player.Character.RightHand` attachment.
- **Why:** PR #7 added a 10-stud distance check (Issue 2 fix). That mitigates teleport-shooting but a determined cheater can still nudge their character + spoof origin within the radius.
- **Pros:** Eliminates the entire "client controls origin" exploit class.
- **Cons:** Client still needs muzzle position for VFX (already does). Need to handle ragdoll / mid-respawn edge cases where RightHand isn't loaded.
- **Context:** Existing client passes `getMuzzle().WorldPosition`; the bug fix in commit 18db315 introduced two-stage aim that compensates for muzzle-camera offset. Server uses client origin directly for raycast.
- **Depends on:** Nothing.

## Refactor: PersistentService helper

- **What:** Extract a `ServerScriptService.PersistentService.lua` ModuleScript exposing `:bind(storeName, defaultFn, validateFn)`. CurrencyService / ShopService / DailyQuestService each become ~30 lines shorter.
- **Why:** Three services duplicate ~30 lines of load/save/PlayerAdded/Removing/BindToClose lifecycle. PR #7 added a load-success flag inline in each (chosen over refactor in Issue 5).
- **Pros:** Smaller diffs in each service; one place to fix bugs in lifecycle handling; trivial to add a 4th persistent service.
- **Cons:** Touches three services in one PR; needs careful verification that behavior is bit-exact.
- **Context:** Decision in Issue 5 was "apply flag in-place per service" to keep PR #7 focused. Refactor is the natural follow-up once we add a 4th persistent thing.
- **Depends on:** PR #7 lands first.

## Tests: DataStore mocks + UI E2E coverage

- **What:** Extend the TestEZ harness (introduced in PR #7 per Issue 5) with (a) a `FakeDataStore` for unit-testing load/save round-trips, (b) Roblox PlaySolo automation for UI flows.
- **Why:** PR #7 covers pure-logic services (cap math, tryBuy/tryClaim state machines). Persistence + UI flows remain untested (44 of 56 paths from the eng-review coverage diagram).
- **Pros:** Round-trips tests catch silent save/load drift; UI E2E catches regressions in ShopController + DailyQuestUI.
- **Cons:** FakeDataStore needs ~50 LOC; PlaySolo automation is fiddly (no first-party harness) — alternative is manual playtest checklist.
- **Context:** TestEZ runner introduced in PR #7. Test plan artifact at `~/.gstack/projects/neallee2012-finalstrike/kunle-pr-7-conflict-fix-eng-review-test-plan-20260510-100337.md` lists every gap.
- **Depends on:** PR #7 TestEZ scaffolding lands.

## Feature: mid-match weapon swap from shop

- **What:** Allow EQUIP from ShopController during PvE phase to immediately re-attach the new weapon model + reset Ammo to its MagSize. Block during PvP.
- **Why:** Currently `MatchManager.initPlayerData` reads `ShopService.getPrimary` only at `startMatch`. Mid-match equip is silently ignored; the new weapon takes effect next match.
- **Pros:** Real UX improvement — players see immediate feedback when they buy + equip; no need to wait an entire match cycle.
- **Cons:** ~30 LOC + edge cases (what if ammo is mid-reload, what if dead, PvP balance — must block to avoid "buy a Wraith Apex during PvP" exploit).
- **Context:** Issue from `/plan-eng-review`. PR #7 adds shop equip mechanism but plumbing only handles next-match. ShopController already shows status text on EQUIP click — could add "Will equip next match" hint as cheap stopgap.
- **Depends on:** Nothing. Could ship as small follow-up PR.

## Architecture: `_G` → require migration

- **What:** Replace `_G.CurrencyService`, `_G.ShopService`, `_G.DailyQuestService`, `_G.MatchManager` with explicit `require(...)` calls (or a `Services.lua` aggregator).
- **Why:** Pre-existing pattern. `_G` is load-order dependent, can't be statically analyzed, and forces defensive `if _G.X then` checks scattered around the codebase.
- **Pros:** Static analysis works; no load-order races; easier to refactor.
- **Cons:** Touches ~10 files (every consumer of `_G.X`); requires careful ordering since current code relies on PlayerAdded loops syncing state by side-effect.
- **Context:** Documented as `_G.MatchManager`, `_G.CurrencyService`, etc. across the codebase. PR #7 follows this pattern consistently. The `_G` antipattern is in many Roblox tutorials but Knit / Aero / Nevermore are all `require`-based.
- **Depends on:** Nothing. Worth doing before adding a 5th service.

## Architecture: phase event signaling

- **What:** Replace `while task.wait(1) do ... mm.CurrentPhase end` polling in `NPCSystem.lua:432-444` and `LootSystem.lua:113-127` with a server-side `BindableEvent` fired by `MatchManager.setPhase`.
- **Why:** Pre-existing pattern. Polling adds 1s of perceived spawn lag and burns two perma-coroutines.
- **Pros:** Instant NPC/loot spawn on phase change; cleaner architecture; no busy loop.
- **Cons:** ~20 LOC change across three files.
- **Context:** Comment in NPCSystem.lua:431 acknowledges this: "Since PhaseChanged fires to clients, we use _G to detect phase from MatchManager." Solution is a BindableEvent (server-only).
- **Depends on:** Nothing.

## Performance: BindToClose parallelization

- **What:** In each persistent service's `BindToClose`, save players concurrently via `task.spawn` + a wait barrier instead of sequentially.
- **Why:** With 12 players × 3 stores × ~200ms each = ~7s sequential. Risk grows under DataStore throttling. BindToClose has 30s budget.
- **Pros:** ~3x faster shutdown; more headroom under throttling.
- **Cons:** ~10 LOC per service; introduces concurrency that must be tested.
- **Context:** Pre-existing pattern in CurrencyService.lua:159, ShopService.lua:193, DailyQuestService.lua:174.
- **Depends on:** Nothing. Cheap win.

## Performance: LootSystem bobbing → Heartbeat

- **What:** Replace per-pickup `task.spawn` 33Hz bob loop with a single `RunService.Heartbeat` driving all active loot in one pass.
- **Why:** ~8 pickups × 33 events/sec = 264 coroutine switches/sec. Negligible but unnecessary.
- **Pros:** Cleaner; trivially scales to 100+ pickups.
- **Cons:** ~15 LOC refactor.
- **Context:** LootSystem.lua:39-48. Pre-existing pattern.
- **Depends on:** Nothing.

## Performance: mobile rendering pass

- **What:** Audit PointLight count, hit-spark Parts, NPC highlights, NPC PointLights for mobile FPS impact. Probable changes: cull distant lights, replace some hit sparks with ParticleEmitter.
- **Why:** PR #7 fix to WeaponHit (Issue 7) cut broadcast volume but each receive still creates a Part + PointLight + tween. NPCs each carry 1-2 PointLights. Mobile clients have tight light budgets.
- **Pros:** Playable on mobile; fewer dropped frames during PvP.
- **Cons:** Requires actual mobile device testing or Roblox device emulator.
- **Context:** Pre-existing pattern; PR #7 didn't make it worse.
- **Depends on:** Mobile QA target audience confirmed.

## Game design: `FirstWinDaily` reward

- **What:** Either implement first-win-of-the-day bonus payout in `MatchManager.endMatch` or remove `GameConfig.ECONOMY.Rewards.FirstWinDaily` from config.
- **Why:** `GameConfig.lua:100` defines it (`FirstWinDaily = 300`) but no code references it. Dead config.
- **Pros (implement):** Real day-one retention hook — extra +300 on the day's first match win on top of `PlacementWin`.
- **Pros (remove):** Clean up dead config.
- **Cons (implement):** Requires per-player day-tracker (similar to DailyQuestService) — could just reuse DailyQuestService's `Date` field.
- **Context:** Found during PR #7 review. Probably an artifact of an earlier scope that wasn't fully wired.
- **Depends on:** Nothing.

## Anti-cheat: rate-limit FireWeapon

- **What:** Server-side per-player FireWeapon timestamp; reject calls faster than `weapon.FireRate * 0.9`.
- **Why:** Issue 2 added an origin distance check. A cheater could still spam FireWeapon faster than the weapon's natural rate to multiply DPS within the legal radius.
- **Pros:** Enforces fire-rate budget server-side; prevents auto-clicker / packet-spam exploits.
- **Cons:** ~10 LOC per-player table; must account for client ping (allow some grace).
- **Context:** Currently FireRate is enforced only on the client (`canFire = false; task.delay(FireRate, ...)`).
- **Depends on:** Nothing.

## Game design: quest progress overflow handling

- **What:** Decide what happens when player exceeds `quest.Target` (e.g. kill 30 NPCs but target is 20).
- **Why:** `DailyQuestService.recordEvent` line 111 caps at target. If config target later increases (20 → 25), already-saved progress at 20 doesn't reflect the actual count of 30.
- **Pros (don't cap):** Lossless. Future config changes work.
- **Pros (current cap):** Saved value stays bounded; prevents huge stored numbers.
- **Cons (don't cap):** Saved progress numbers grow without bound.
- **Context:** PR #7 introduces this. Acceptable as-is for a single quest cycle but bites if you ever raise targets retroactively.
- **Depends on:** Nothing.
