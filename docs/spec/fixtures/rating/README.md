# Rating fixtures

Fifteen JSON files. Each has `id`, `title`, `kind`, `case` (which review case it covers), `expect_summary` (plain words) and `checks` (machine-checkable rules). `tools/reference/rating_sanity.py` reads every file in this folder and evaluates the checks; the GDScript test suite must read the same files and evaluate the same rules.

Hole geometry is integer yards in a hole-local frame (`x` lateral, `y` forward, tee at the origin). See `docs/spec/rating/rating-engine.md` section 2.1 for the fields. Trees may be given as `{t:"tree", rect, count}`; the loader expands them as described there.

Rule format: `{text, op, a, b?, margin?, lo?, hi?}` with `op` in `gt ge lt le eq between`. `a` and `b` name a result as `<hole>.<field>` (fields: `score_pm A I Len B F par valid unch pick comps`, where `unch` is the forced penalty rate `forced_pm`, `pick` is `pickup_pm`, `comps` is corridor count), `course:<name>.<field>` (`course_x10 mean low_third n_dup`), or a literal integer. The rule holds when `a op (b + margin)`.

Reference seed for all rating fixtures: `save_secret = 0x12345678`, `rating_epoch = 1`, `slot_id` as given in each hole, calm dry condition unless a fixture says otherwise. The seed is `H32(secret, epoch, slot_id, 0x4D48)`.

| File | Review case | What it proves |
| --- | --- | --- |
| 01 | case 1 | empty, no-tee and no-green holes: invalid, score 0 |
| 02 | case 2 | plain wide par 4: fair, accurate, no imagination, mediocre |
| 03 | case 3 | 500 decorative trees: Beauty rises to a cap, total gain at most 40 permille |
| 04 | case 4 | 900 yard par 5 scores far below 520 yard par 5 |
| 05 | case 5 | central lake with safe routes: fairness not below plain, imagination up |
| 06 | case 6 | only landing zone is a narrow island in water: fairness very low |
| 07 | case 7 | 18 copies against 18 varied holes |
| 08 | case 8 | hash vectors, golden sim hash, tree nudge, epoch spread |
| 09 | case 9 | 14 malformed inputs rejected with codes; embedded score ignored |
| 10 | case 10 | tournament snapshot, sustained score, prestige of a dressed-up course |
| 11 | extra | nine decent plus nine dead holes: roll-up drags the score |
| 12 | extra | unplayable hole: all scratch golfers pick up, invalid, score 0 |
| 13 | extra | a mirrored copy is detected as a duplicate |
| 14 | extra | wind and rain change results deterministically |
| 15 | case 10 tie-break | leaderboard tie-break order |

Fixtures 07 and 11 hold many generated holes; they were produced by a script and the JSON is the source of truth. Golden values in fixture 08 (`golden`, `hash_vectors`) come from the Python reference model, not from GDScript. If the model changes, regenerate them and bump the engine version.
