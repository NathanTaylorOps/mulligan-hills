# Localization string file conventions

English only at launch, but all text lives in keyed string files from day one (Master Plan). File: `game/data/strings/en.json` (path proposed; workstream that owns UI shell confirms). Format: `strings.schema.json`. Checked by `validate.py` logic that CI must run on the real file (length, placeholders, spacing, no em dash).

## Keys
- Lowercase, dot separated, 2 to 5 segments, segment chars `a-z 0-9 _`: `area.subarea.name`. Regex in the schema. Max 80 chars.
- Areas: `ui.common.*`, `ui.<screen>.*`, `building.<id>.name|desc|spec_a|spec_b|tier1..5.name`, `tournament.<level>.*`, `advisor.<axis>.<reason_code>` (tied to rating-engine reason codes; add `.v1..v3` for variants), `complaint.*`, `card.<card_id>.title|body|a|a_out|b|b_out|c|c_out`, `commission.<template_id>.title|body|success|fail`, `tutorial.step<NN>.*`, `achievement.<id>.name|desc`, `toast.*`, `error.*`, `preset.course_name.NNN`, `preset.club_name.NNN`, `preset.plaque.NNN`, `regular.<id>.name|story`.
- Keys are permanent identifiers. Renaming a key is a data migration; never reuse a key with a different meaning.
- Data files reference text only by key, never by literal text.

## Entry fields
`text` (string), `ctx` (where it shows and who speaks, 3 to 160 chars, required), `max` (max characters, required), `placeholders` (declared list), `status` (`draft` -> `edited` -> `approved`; only `approved` ships in a release build), `plural_of` (optional, for a plural companion key).

## Placeholders
`{name}` with lowercase snake names. Text placeholders must equal the declared list exactly. Values are formatted by code (numbers, money) before substitution. No positional placeholders, no HTML or BBCode except the single tag pair `[b]..[/b]` (tutorial highlights only).

## Length limits (max characters, English; other languages assume +40% growth so UI must not clip)
| Kind | Limit |
| --- | --- |
| Button | 16 |
| Screen title, building name, tier name | 24 to 32 |
| Toast | 80 |
| Advisor sentence | 120 |
| Complaint feed line | 90 |
| Tutorial step | 140 |
| Card title | 28 |
| Card body | 300 |
| Card choice label | 40 |
| Card outcome | 160 |
| Building description | 140 |
| Achievement name / description | 28 / 90 |
| Preset course/club name | 28 |
| Store-facing strings | governed by store limits, not this file |

## Style rules (from the voice guide, to be written by the content owner)
Plain direct sentences, no em dashes, no emoji, no real people, clubs, tournaments or brands, no "SimGolf" terms. One space between sentences. No trailing spaces. Fictional sponsors only.

## Process
AI drafts in batches into `draft`, Nathan edits to `edited`, then `approved`. CI checks: length <= max, placeholder match, duplicate text within an area, banned-phrase list, profanity list, every key referenced by data exists, no orphan keys.
