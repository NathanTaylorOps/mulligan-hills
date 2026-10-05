# Phase 1: progression, achievements, streak (`game/core/progression/`)

Status: 4 Oct 2026. Code and tests written, **NOT YET RUN** (no Godot in the sandbox). The point formulas and the refresh golden values come from a small Python mirror (scratch script, not committed). Expect small parse fixes on the first CI run.

Owner paths: `game/core/progression/`, `game/tests/progression/`, runtime copies `game/data/achievements.json` and `game/data/progression.json` (byte identical to `docs/spec/data/`; after any change run `cp docs/spec/data/achievements.json docs/spec/data/progression.json game/data/`). Draft English text for all 61 achievements and 20 level titles: `progression_strings_en.json` (status draft: names come from ids and descriptions from the conditions, wording needs a human pass).

## README block

**Purpose.** Club level, club prestige points, achievements and the daily streak. Achievement unlock conditions are data (`all` conditions on a stats Dictionary, 61 achievements, schema minimum 40). Stats are high-water marks, so nothing is ever lost and no achievement is missable. A broken streak resumes at a reduced value, never at zero.

**Public API.**
- `MHProgressStats`: `observe(snapshot)` (only raises, unknown keys and non-integers ignored, clamped 0..1e9), `raise_to`, `observe_tiers(tiers)` (tier_<building>, tier_sum, tier5_count, buildings_built), `observe_hosted(levels, hosted, attempted)`, `value_of`, `to_dict/from_dict`. `STAT_KEYS` equals the schema enum (39 stats; a test compares them when the docs folder is reachable). `bonus_prestige` is an extra non-achievement stat.
- `MHAchievements`: loads and validates the catalogue, `is_met`, `newly_unlocked(stats, unlocked)`, `progress_rows(stats, unlocked)` (row keys exactly as `MHGameStateView` documents: `id, category, tier, points, hidden, earned, progress, target`), `total_points`, `get_def`.
- `MHStreak`: `configure(streak_block)`, `record_active(day)`, `display_streak(day)`, `milestone_points_total`, `to_dict/from_dict`.
- `MHProgression` (the facade the game holds): `load_defaults()`, `stats`, `streak`, `achievements`, `points_breakdown()`, `club_points()`, `level()`, `points_for_next_level()`, `unlocks_up_to_level`, `is_unlocked(unlock_id)`, `add_bonus_prestige`, `record_active_day(day)`, `observe_tournaments(state)`, `observe_daily(state)`, `refresh()`, `achievement_rows()`, `to_save_ids()/load_save_ids(ids)` (the existing `progress.achievements`), `to_dict/from_dict`.

## Rules as implemented

Club prestige points are computed from monotone stats, never stored, so they only go up: `per_hole x holes_max`, `per_building_tier_step x tier_sum`, `per_course_score_point x best_course_score`, `min(members_max / members_div, members_cap)`, `challenge_completed x completed + challenge_attempted x (attempted - completed)`, `commission_done_base x commissions_done`, plus the points of unlocked achievements, plus claimed streak milestones, plus `bonus_prestige` (tournament prestige awards and event card `add_prestige`). Level = highest row of the levels table whose `prestige_needed` is at most the points (20 levels, 0 to 22,000). The `level` stat is written back so the `club_level_five` and `club_level_ten` achievements can use it; `refresh()` therefore loops until stable (an achievement can lift the level, a level can unlock an achievement), at most 12 passes.

`refresh()` returns `{new_achievements, level_before, level, level_up, new_unlocks}`; the caller awards the earned token per new achievement (`MHTokenLedger` rule `achievement`, key = achievement id) and shows the unlock toast. Level unlock ids (`commissions`, `plaque_bronze`, `flag_style_2`, `banner_1`, ...) are only reported, nothing consumes them yet.

Streak (numbers from `progression.json`, interpretation mine): one active day extends the streak when it is the next day. A gap of 1 to `max_bridge_days` (2) missed days is bridged if a grace is available (one grace per gap); the player starts with `grace_start` (1), regains one each time the streak reaches a multiple of `grace_regain_every_days` (7) up to `grace_max` (2). Any other gap resumes at `floor(streak x resume_percent / 100) + 1` (50%, minimum 1). Each milestone (3, 7, 14, 30, 60, 100 days) pays once per save. A day not after the last active day is ignored (clock set back).

## Wiring

- Feed stats whenever the underlying number changes (cheap, only raises): `stats.observe({"holes_max": n, "holes_good_max": n, "best_hole_score": s, "best_course_score": c, "parcels_max": p, "members_max": m, "reputation_max": r, "lifetime_earned": e, "days_played": d, "commissions_done": n, "commission_kinds": k, "cards_played": n, "golfers_finished": n, "best_axis": a, "tutorial_done": true})`, `stats.observe_tiers(purchased_tiers)`, `observe_tournaments(state)`, `observe_daily(state)`. Then `refresh()` once per game day and after each purchase or event.
- Event cards: for an `add_prestige` effect call `add_bonus_prestige(amount)` (positive amounts only; negative effects are ignored on purpose, prestige never drops).
- Save: `progress.achievements = progression.to_save_ids()`. Stats and streak: `progression.to_save_progress()` gives `achievements`, `stats`, `streak` (schema `progress.stats`, `progress.streak`); `load_save_progress(progress)` validates first, then assigns.
- Platform: `MHGamesService` achievements (Play Games and Game Center) are not wired; the platform doc says only leaderboards exist.

## Tests (`game/tests/progression/`)

`test_achievements.gd` (stats monotone, bad input, tiers and hosted helpers, stat keys equal the schema enum, 61 well formed unique achievements with 1140 total points, unlock rules, all-conditions rule, file order, progress rows, op variants, validation failures, game copy equals docs copy), `test_progression.gd` (points golden 810 and 955 after refresh, member cap, level table edges, unlock lists, refresh loop with the level achievement, tournament ladder, no drops, bonus prestige, streak points, helper observers, save id filtering, round trips, bad saves, bad data), `test_streak.gd` (grace, bridge of two days, soft resume, regain, milestones total 470 over 100 days, display value, round trips, bad config). Helper `progression_fixture.gd`.

## NOT YET RUN / unverified

All `.gd` here. Python mirror verified the formulas and the refresh result of three scenarios. Streak scenario expectations were derived by hand from the rules above (no mirror run).

## Risks and follow-ups

1. Save schema: FIXED (`progress.stats`, `progress.streak`, `progress.daily` are optional fields of v1). Streak active-day and token awards for achievements/challenges are wired by the caller of `MHProgressBridge`, not yet by a real adapter.
2. Achievement ids that were saved but later removed from the catalogue are dropped silently on load (`load_save_ids` returns how many).
3. Points are placeholders; at the shipped numbers my rough estimate for a completed game plus a month of dailies is 4,000 to 5,000 points, so levels above 12 or so are far away. Tune once the economy and content exist.
4. Platform achievements (store achievements) are out of scope.

## For Nathan

1. Streak: I read "grace 1, max 2, bridge 2 days" as one grace forgives one gap of up to 2 missed days. Alternative: each missed day costs one grace. Which do you want?
2. Achievement wording is auto-generated from the conditions (draft, in the strings file): do you want to write names and descriptions yourself, or have me polish a set for review?
3. Should any achievement or level grant tokens beyond the 1 earned token per achievement already in the token ledger?


## 5 October: clarified RPG and visual rewards

See `rpg_scope.md` for Nathan’s golfer/club RPG requirements and launch reconciliation proposals. Existing club progression is not personal golfer attributes. Existing plaque/flag/paint unlock IDs are reported but not yet applied to procedural art. Trophy ownership/selection and building skins need catalogues, validated save fields and scene consumers. No new XP or payout numbers have been implemented or implied by the economy-only campaign report.

Launch classification resolved: DEC-072–075 require the golfer career and visible reward systems in v1. Attribute/XP numbers and cosmetic save/schema/scene implementation are still pending; existing club levels are not a substitute for golfer progress.
