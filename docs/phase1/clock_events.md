# Phase 1: game clock, time-skip tokens and event cards (`game/core/clock/`, `tokens/`, `events/`)

Status: 5 Oct 2026. DEC-070 pacing update; Python clock boundary checker PASS. NOT YET RUN: no Godot here. Python mirrors computed the golden values (clock accumulator, PCG32 draws, card eligibility). CI has not seen the new tests.

## 1. What was built

- `clock/mh_game_clock.gd` `MHGameClock` (DEC-052, DEC-053). Pure logic, never reads the system clock; the caller passes real microseconds per frame. A game day is 660 game minutes (11 hours, day only). At 1x a day is 1,500 real seconds (25 minutes), 26.4 game seconds per real second. Fractions are exact: an integer accumulator holds (real us x game minutes) and rolls over at 1,500,000,000, so any slicing of the same total time gives the same result. Speeds 1, 2, 4, 8. `step(delta_us, ledger)` returns flat int rows `[type, day, value]`: `EV_HOUR` (value = hour of day 1 to 11), `EV_DAY` (new day number), `EV_SPEED_DROPPED` (old speed). When hour 11 ends, EV_HOUR comes first, then EV_DAY. `pause`/`resume`, `set_time`, getters, `to_dict`/`from_dict` (rejects bad data, JSON safe).
- Token drain: above 1x the clock takes whole tokens from the ledger in advance (`prepaid_credit`, units of token x real microsecond). Rates: 2x costs 1 token per real minute, 4x costs 2, 8x costs 4 (so one token buys 60 s of 2x, 30 s of 4x, 15 s of 8x). When tokens run out mid-frame the rest of the frame runs at 1x and a speed-dropped event is emitted. `request_speed` needs at least one token or leftover credit; 1x is always allowed. There is no purchase code in the clock.
- Catch-up cap: one delta above 2 s is treated as the app having been suspended. It is clamped to 120 s at 1x, spends no tokens, and the rest is discarded (`last_discarded_us`). 52.8 game minutes pass per capped suspension (at most 53 minute boundaries); there is no offline progress beyond that.
- `tokens/mh_token_ledger.gd` `MHTokenLedger` (DEC-053). Two balances: `earned` (cap 999) and `paid` (cap 100,000). Earned tokens come from reward rules, once per (rule, key): daily_login 2, challenge_complete 3, achievement 1, tournament_result by place 10 / 6 / 4 / 1. Paid tokens change only through `apply_validated_purchase(receipt_id, tokens)` (idempotent per receipt id, called only after server validation) and `apply_refund(receipt_id)` (idempotent, never takes more than the paid balance holds, never touches earned). Spend order: earned first, then paid. `spend` is atomic, `spend_up_to` is for the clock. Tokens buy only time speed-ups and bankruptcy recovery, never cash or progress (the ledger has no cash API). `to_dict`/`from_dict` (JSON safe) and `save_to`/`load_from` (own crash-safe file `user://tokens.json` through `MHJsonFile`). The ledger is NOT in the save slots, and the save validator rejects token-like keys.
- `events/mh_event_deck.gd` `MHEventDeck`. Loads `game/data/event_cards.json`, validates structure (schema, weights, unique ids, choices, effect ops and required fields). Eligible cards are collected in file order; a weighted draw uses one `MHRng.bounded(total_weight)`; `roll_daily` first spends one `bounded(1000)` against the permille chance, then draws; no eligible card consumes no random numbers. Conditions: min_day, min_avg_hole_score, min_members, min_tier / max_tier, seasons, requires_tags / forbids_tags, requires_flags / forbids_flags, cooldown_days, once. Effects are data (`add_cash`, `add_reputation`, `add_members`, `add_prestige`, `set_flag`, `clear_flag`, `weather_next_day`, `golfer_flow_pct`); the deck never applies them. `resolve_choice` scales `add_cash` by a percent (remote config `events.event_cash_scale_pct`). `choice_available` checks a choice's `requires` (min cash, min reputation). Save state: `to_dict`/`from_dict`, and `to_card_history`/`from_card_history` in the shape of `progress.card_history` (`card_id`, `last_day`) already in the save schema.
- Data: `docs/spec/data/event_cards.json` has 65 cards (weather 11, member 12, community 12, vip 8, staff 8, finance 8, celebrity 6). All text is golf-flavoured and fictional (made-up names and places, no real brands or people). Game copy: `game/data/event_cards.json` (byte identical; after any change run `cp docs/spec/data/event_cards.json game/data/event_cards.json`). In this round every optional spending choice got a `requires.min_cash` equal to its cost, so a broke club cannot pick it; forced-cost cards keep one ungated choice. Schema `event_cards.schema.json` is unchanged. English strings for every key: `game/core/events/event_cards_strings_en.json` (draft, for the strings owner to merge into the main strings file).

Tests: `game/tests/clock/test_game_clock.gd` (21 cases), `game/tests/tokens/test_token_ledger.gd`, `game/tests/events/test_event_deck.gd`.

## 2. How it is tested, and what is NOT run

All Godot tests are NOT YET RUN. Verified here with Python only:
- `docs/spec/data/event_cards.json` validates against its schema with the `jsonschema` package (65 unique ids, every text key has an English string, no card uses flags yet). `python3 docs/spec/data/validate.py` passes but only checks `event_cards.example.json`, not the full card file; the full file is checked by the `jsonschema` run described here and by the gdUnit tests (65 cards, ids, effect ops, text keys, game copy equals docs copy when the docs folder is reachable).
- Golden values in tests were produced by independent Python mirrors: clock scenarios (speed 2, 4, 8, mixed tokens, frame slicing at 8x), a 10-card draw sequence (`MHRng(20260929, 7)`, summer context), a 12-day daily-roll sequence (`MHRng(555, 3)`, 300 permille), and card eligibility counts.

## 3. Gate 0 criteria

None directly. Determinism relevance: the deck uses only `MHRng` and integers, and the clock uses only integers, so both are safe for the cross-device golden checks later.

## 4. Unverified assumptions

- Same GDScript API assumptions as `save.md` (JSON, FileAccess, DirAccess).
- Whether `res://data/*.json` is packed into Android and iOS exports (see `save.md` risk 8).
- gdUnit4 assertion names used: `assert_int(...).is_between / is_greater / is_greater_equal / is_less_equal`, `assert_array(...).contains_exactly`.

## 5. Risks and follow-ups

1. Historical save-position concern: follow the latest save schema and migration decisions. The live session requests hourly saves, but validated scene/save wiring remains unfinished; internal clock snapshots are not yet official slot storage.
2. Token rates are locked by DEC-053/070. DEC-064 prohibits paid tokens in v1; historical paid-ledger plumbing is not a v1 store offer.
3. Bankruptcy recovery with tokens is not coded; `MHTokenLedger.spend(n)` is the call it should use.
4. The ledger file `user://tokens.json` is plain JSON: a player on a rooted device can edit earned and paid balances. Paid-token integrity needs a server record (validated receipts) if cheating matters. Earned tokens are low value and are not protected.
5. A full earned balance still consumes the daily-login key (the claim is lost, not postponed).
6. Receipt ids are remembered for the last 500 purchases only.
7. Event card `weather_next_day` and `golfer_flow_pct` effects are data only; the economy and sim owners must apply them.

## 6. For Nathan

No action needed now. Questions:
1. Event card tone: read 5 or 6 cards in `game/core/events/event_cards_strings_en.json` (search "card.vip_visit", "card.goose_invasion", "card.insurance_bill") and tell me if the humour level is right.
2. Time-skip rates remain locked; no paid token packs in v1 (DEC-064).
3. If the app is backgrounded, the game now moves forward by at most 52.8 game minutes and no more. Agree, or do you want longer offline progress?


## DEC-070 snapshot compatibility

Clock snapshots now include `real_us_per_day`. Missing values mean the legacy 15-minute period; loading scales the fractional-minute accumulator into the 25-minute period. Unsupported periods reject. World day/minute units stay unchanged. This is an internal clock snapshot change, not completed slot-save wiring. The editor toolbar now exposes pause/resume, and session tests cover course submission while paused. Godot/device evidence remains pending.
