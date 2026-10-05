# Phase 1: daily challenge (`game/core/challenges/`)

Status: 4 Oct 2026. Code and tests written, **NOT YET RUN** (no Godot in the sandbox). Golden challenges in the tests come from an independent Python mirror of the generator (scratch script, not committed). Expect small parse fixes on the first CI run.

Owner paths: `game/core/challenges/`, `game/core/mh_data_json.gd` (shared with tournaments), `game/tests/challenges/`, runtime copy `game/data/daily_challenges.json` (byte identical to `docs/spec/data/daily_challenges.json`; after any change run `cp docs/spec/data/daily_challenges.json game/data/daily_challenges.json`). Draft English text: `challenge_strings_en.json` (status draft, for the owner of `game/data/strings/en.json`).

## README block

**Purpose.** DEC-016 and DEC-059: the daily challenge stays in v1 with a remote kill switch. Every UTC day has one challenge: a par, a few rating-axis minimums or maximums, a length bound and a minimum score, all derived from the day number so every device and the server get the same challenge. This module generates and judges it and keeps the player's attempts. It does not rate holes (the rating engine does) and does not talk to the server.

**Public API.**
- `MHDailyChallenge`: `load_from_file/text/dict`, `generate(day)`, `today(day, kill_switches)` (returns `{}` when the feature is off), `sim_seed(day)`, `evaluate(challenge, entry)` (static), `axes_from_rating(rating_result)` (static), `day_number_from_unix`, `minutes_until_rollover`, `is_feature_on(kill_switches)`, data getters (`attempts_per_day`, `history_days`, `local_board_cap`, `template_at`, `template_by_id`).
- `MHKillSwitch.is_on(kill_switches, key)`: reads the remote-config `kill_switches` object (true = ON). Fail open: a missing key, a missing config or a non-boolean value leaves the feature ON, only an explicit `false` disables it. The same class serves the `tournaments`, `cloud_sync`, `analytics`, `purchase_flow` and `notifications` switches.
- `MHDailyState`: per player. `record_attempt(day, completed, score_pm, fairness_pm)`, `attempts_left(day)`, `attempts_used`, `best_score(day)`, `completed_on(day)`, `history()`, `board()`, counters `attempted_days` and `completed_days`, `to_dict/from_dict`.

## Generation (stable draw order, pinned by tests)

`rng = MHRng(H32(generation_salt, day, 0x4D48), stream 1)`. Draws: difficulty (`bounded(sum of difficulty_weights)`, 0 easy / 1 medium / 2 hard, weights 50/35/15), template (weighted, file order), par (`bounded(par count)`), then one `bounded(3)` per threshold in the order axis minimums (accuracy, imagination, length, beauty, fairness), axis maximums (same order), `max_length_yd`, `min_length_yd`, `min_score`. A threshold pair `[easy, hard]` gives `easy + round((hard - easy) x difficulty / 2)`, plus jitter (-1, 0 or +1) x `jitter_step`, rounded to `round_step`, clamped between the pair ends (a hard challenge is never easier than the easy end) and into 0..100 or 50..700. Output keys: `day, challenge_id (= day), template_id, difficulty, par, axis_min {axis: int}, axis_max {axis: int}, max_length_yd / min_length_yd / min_score (when the template has them), target_score, title_key, desc_key, sim_seed`.

`target_score` is `min_score` when present, otherwise the rounded mean of the axis minimums. `sim_seed` = `MHRMath.daily_seed(day, sim_seed_tag)` = `H32(0xDA11, day, 55825, 0x4D48)`, the public seed of the rating spec (section 4), so every player gets the same simulation draws and the server can re-simulate.

## Judging

`evaluate(challenge, entry)` with `entry = {valid, par, length_yd, score (0..100), axes {accuracy, imagination, length, beauty, fairness} (0..100)}` returns `{completed, rows}`; rows are `[key, met, have, need]` with keys `valid, par, axis_min:<axis>, axis_max:<axis>, max_length_yd, min_length_yd, min_score`. `axes_from_rating` converts the rating engine's permille `A, I, Len, B, F` to 0..100 (round half away). Dead or invalid holes never complete a challenge.

## Player record

Three attempts a day (`attempts_per_day`). A new UTC day resets the attempts and archives the old day into a 30 day history. The local board keeps the best 90 attempts of this player (score, then fairness, then earlier day), no names. `attempted_days` and `completed_days` count days, not attempts (a day with three tries counts once), and feed `challenges_attempted` and `challenges_completed` (achievements, prestige). A clock set backwards is refused (`past_day`). The first attempt of a day returns `first_attempt = true`: call `MHProgression.record_active_day(day)` then (see `progression.md`).

## Wiring

- `MHGameStateView.daily_challenge()`: `enabled = MHDailyChallenge.is_feature_on(switches)`, `title_key/desc_key/target_score` from `today(day, switches)`, `attempts_left/attempts_total` from the state, `best_score = state.best_score(day)`, `streak_days = progression.streak.display_streak(day)`, `ends_in_minutes = MHDailyChallenge.minutes_until_rollover(unix_now)`, `board` from `state.board()` (map `score_pm / 10`; the UI wants a `name`: use a preset label, names are preset-only in v1).
- Intent `daily_play`: build the hole from the editor, rate it with `ctx.hole_seed = challenge.sim_seed`, call `evaluate(challenge, entry)`, `state.record_attempt(...)`, `progression.observe_daily(state)`, `progression.refresh()`, and upload with `submit_daily(seed, payload)` when online and the switch is on (server checks are bounds and rate checks only, DEC-036).
- Day number: `MHDailyChallenge.day_number_from_unix(unix)` from the platform clock. The server clock should win when the two disagree by more than a day (a player can set their device clock; the local board is not trusted).

## Tests (`game/tests/challenges/`)

`test_daily_challenge.gd` (8 golden days incl. `sim_seed`, determinism, 400 day mix 192/146/62 and all 12 templates seen, thresholds inside the pair ends, kill switch semantics incl. fail-open, day and rollover maths, evaluate rows, validation failures, game copy equals docs copy), `test_daily_state.gd` (attempts, day roll, clock back, counters per day, fairness tie break, board order and cap, history cap, round trips, bad data).

## NOT YET RUN / unverified

All `.gd` here. Python mirror verified the generator and the distribution. Unverified: whether the rating engine's `A, I, Len, B, F` are permille 0..1000 (assumed from `score_pm`), what unit its hole length `L` is in (the caller passes `length_yd` explicitly), and that `daily_seed`'s `slot_id` is meant to be `sim_seed_tag` (the data file has the field but no doc says how it is used).

## Risks and follow-ups

1. `DailyState` (and the streak and stats in `progression.md`) have no home in `save.schema.json`: `progress` is closed (`additionalProperties: false`). Options: add `progress.daily` and `progress.stats` to the schema (preferred, they should follow the save to a new device and into cloud save), or keep a small `user://` file like `MHTokenLedger`.
2. Thresholds are placeholders until the rating engine's real score distribution is measured (the data file says so). The hard challenges may be unreachable or trivial.
3. The five axis keys `accuracy, imagination, length, beauty, fairness` are the rating spec's names; the IP lawyer review of those names (DEC open item 9) applies to the challenge text too.
4. The local board is the player's own history, not a social board. The online board and its tie-break (score, fairness, server receive time, submission id) belong to the server and `MHRTournament.rank`.

## For Nathan

1. Which day should count as an "active day" for the streak: the first daily challenge attempt (my recommendation) or any play session?
2. If the daily challenge switch is turned off while a player has attempts left, those attempts are simply unavailable until it is back on. OK, or should unused attempts carry over?
