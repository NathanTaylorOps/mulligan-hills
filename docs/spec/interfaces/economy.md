# Interface: Economy (`game/core/economy/`, owner assigned in Phase 1)

## Implementation status (29 Sep 2026)
No code exists (`MHEconomy`, `MHEconomyParams`, `MHClubState`, `MHDayLedger`, `MHDaySummary`, `MHCourseRating`, `MHResult` are drafts). Numbers live only in `docs/spec/data/buildings.json` (costs, upkeep, parcels) and `remote_config.example.json` (`start_cash` 40000, green fee 5..250); all are placeholders per `docs/CONTRACT.md` and `docs/DECISIONS.md` open item 4.

Purpose: cash, fees, members, upkeep, land purchase, daily accounting, difficulty modes. Integer dollars. Deterministic given the day summary from the sim and the save RNG. No premium currency and no real-money path exists in this module (pillar).

```gdscript
class_name MHEconomy extends RefCounted
signal cash_changed(new_cash: int, delta: int, reason: int)      # UI only
signal member_count_changed(members: int)
func setup(params: MHEconomyParams, state: MHClubState) -> void   # params from buildings.json + remote config (clamped)
func cash() -> int
func can_afford(cost: int) -> bool
func spend(cost: int, reason: int) -> MHResult                     # fails if cash < cost unless mode is sandbox
func earn(amount: int, reason: int) -> void
func set_green_fee(fee: int) -> MHResult                           # clamped to [fee_min, fee_max]
func green_fee() -> int
func settle_day(summary: MHDaySummary, rating: MHCourseRating) -> MHDayLedger   # revenue, upkeep, wages, members joined/left, new cash
func members() -> int                                              # from Clubhouse tier, course score, fee; target time to 50 members set in the economy sim
func parcel_cost(parcels_owned: int) -> int                        # base * growth^k, integer
func buy_parcel(parcel_id: int) -> MHResult
func recovery_offer() -> MHRecoveryOffer                           # rule when cash and income cannot cover upkeep (bankruptcy protection)
func mode() -> int                                                 # MHMode.RELAXED, STANDARD, TYCOON, SANDBOX
```
`MHDayLedger`: `revenue_rounds`, `revenue_ancillary`, `revenue_members`, `upkeep`, `wages`, `net`, `members_delta`, all int.

## Rules
- All costs come from data files or clamped remote config, never literals in code.
- Cash sinks: upkeep (per building tier, `upkeep_per_day`), wages, renovation, tournament costs. Cash floor at zero outside sandbox; recovery rule applies before a bankrupt state.
- Fee has a pace/queue cost input from the sim so the revenue-maximising fee is not the floor.
- Start cash sized so the first purchase lands within about 5 minutes (tuned by simulation; economy sim runs in CI as a test with pass/fail targets).
- Ironman: `mode` is orthogonal; ironman disables reload, not economics.

## Consumers
UI, buildings (spend), save (state), tournaments (costs and rewards).

## Contract tests
Ledger arithmetic (sum of parts equals net), no negative cash, clamps, determinism of `settle_day` for a fixed summary, bot-driven economy sim thresholds.
