# Tests

TestEZ-based unit tests for pure-logic helpers extracted from server services.

## Setup (one-time)

1. Download TestEZ:
   - Repo: https://github.com/Roblox/testez
   - Place the `TestEZ` ModuleScript folder in `ReplicatedStorage`.
2. In Studio, open `Tests/Runner.server.lua` and set `script.Disabled = false`.
3. Playtest the game — test results print to the Output window.
4. Set `script.Disabled = true` again before shipping (so tests don't run in production).

## Coverage

| Module | Status | Notes |
|--------|--------|-------|
| `CurrencyMath.spec` | ✅ | 10 tests covering per-category cap, total cap, clamp, exhaustion. |
| `ReloadLogic.spec` | ✅ | Reload eligibility, authoritative token/cancellation, stale operations, reserve-ammo accounting, partial reloads, and invalid config. |
| `ShopService.spec` | ❌ TODO | `tryBuy` state machine. Blocked: ShopService.lua has DataStore + RemoteEvent side effects on require. Needs a similar `ShopLogic.lua` extraction. See TODOS.md. |
| `DailyQuestService.spec` | ❌ TODO | `recordEvent` + `tryClaim` + `ensureFreshDay`. Same blocker as ShopService. |
| `MatchManager.spec` | ❌ TODO | Placement math in `eliminatePlayer` (death order → top3/top5). Pure logic; needs extraction. |

## Adding a new spec

1. Create `Tests/<Module>.spec.lua` using TestEZ syntax (`describe`/`it`/`expect`).
2. Module must be requireable without yielding (no `WaitForChild` on runtime
   objects, no DataStore calls). Extract pure logic into `ServerStorage.<Module>Math.lua`
   if needed.
3. The runner picks up `*.spec.lua` files automatically.

## Why pure-logic extraction

Roblox services like `CurrencyService` yield on `ReplicatedStorage:WaitForChild("GameEvents")`
during require, register `Players.PlayerAdded` connections, and call DataStore APIs.
None of that is testable in isolation. The pattern in this codebase is to extract
the side-effect-free arithmetic into a separate ModuleScript (`CurrencyMath`),
test it directly, and have the service module call it. Slowly grow this pattern
as more pure logic is identified.
