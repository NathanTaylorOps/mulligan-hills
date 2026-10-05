# App Store listing draft (later: iPhone comes after Android, DEC-002)

Status: DRAFT 2026-10-04, not needed until the iPhone build exists. Limits are the ones I know (VERIFY in App Store Connect). Same "[CONFIRM SHIPS]" rule as the Play listing.

| Field | Draft | Limit |
| --- | --- | --- |
| Name | `Mulligan Hills` (14) | 30 |
| Subtitle | `Build Your Golf Legacy` (22) (DEC-001) | 30 |
| Promotional text | `Shape the land, design every hole, and watch golfers play your course. Try the free demo, then unlock the full game once. No ads.` (129) | 170, can be changed without a new build |
| Keywords | `golf,tycoon,course,builder,design,simulation,management,club,tournament,idle,strategy,sandbox` (93) | 100 characters, comma separated, no spaces. Do not repeat words already in the name or subtitle; do not use other companies' names |
| Description | Use the Play full description with the "free demo, one unlock" paragraph (about 2,500 characters) | 4000 |
| Category | Primary: Games. Secondary subcategory: Simulation (and optionally Sports) | VERIFY |
| Price | Free, in-app purchase `mh_full_unlock` (non-consumable), tier equal to 4.99 USD | The product id must be created exactly like this (DEC-060) |
| Support URL | a page that has the support email | required |
| Marketing URL | optional | |
| Privacy Policy URL | same page as Play | required |
| Copyright | `2026 <your legal name or entity>` | open question 4 |

## Things App Store review checks that this game triggers
| Item | Our position | Action |
| --- | --- | --- |
| Account deletion inside the app (Guideline 5.1.1(v), VERIFY wording) | Settings > Delete account calls `account` function (`delete_account`) | Test on a fresh install before submit |
| Sign in options | Anonymous accounts need no sign in. If "link Google" is offered (DEC-012), Apple may require an equivalent privacy-friendly sign in option (VERIFY the current rule) | Open question 7: either do not offer Google sign in on iOS, or add Sign in with Apple |
| Restore purchases button | Present in Settings (DEC-028) | Keep |
| In-app purchase review screenshot and notes | Needed for `mh_full_unlock` | Take from the unlock screen (which still has no UI, `docs/phase1/ui.md` section 5) |
| Export compliance (encryption) | The game only uses standard HTTPS provided by the OS and Godot; answer the questionnaire and set the Info.plist key (VERIFY exact key and answers) | Lawyer or Apple docs; do not guess |
| App Privacy "nutrition label" | See `data_safety.md` section 4 | Fill in App Store Connect |
| Age rating questionnaire | See `content_rating_notes.md` | Fill in |
| Tracking (App Tracking Transparency) | No tracking across other companies' apps or sites, no advertising id | State "no tracking" only after the lawyer confirms |
| Demo or review account | None needed; every feature works with the hidden anonymous account | Say so in the review notes |
| Review notes | "Free demo; `mh_full_unlock` is a one time unlock; the daily challenge and cloud save use an anonymous account that the app creates automatically; analytics is off unless the player opts in on the first screen." | Paste |

## iOS-only backend gap
`verify-apple` (App Store Server API receipt check) is not written (`supabase/functions/README.md`). Until it exists, iPhone cannot verify the unlock server side (DEC-030).
