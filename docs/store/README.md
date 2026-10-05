# docs/store : store readiness pack (Google Play first, App Store later)

Written 2026-10-04 by the backend and store workstream. Status: DRAFTS for Nathan and a lawyer. **Nothing here is legal advice, nothing here has been reviewed by a lawyer, and nothing here claims that any text is legally valid, complete, or compliant.** Every legal document is marked DRAFT FOR LAWYER REVIEW at the top and must not be published before a qualified lawyer has read it.

Rules used while writing: no invented store policies or prices (anything I could not confirm is marked VERIFY with where to check); the game text only claims what the repository says is built or decided (anything not yet built is marked CONFIRM SHIPS); no competitor names or other people's trademarks in listing text.

| File | What it is | Who must act |
| --- | --- | --- |
| `listing_google_play.md` | Title, short and full description, graphics list, release notes, store settings | Nathan approves; confirm features before submit |
| `listing_app_store.md` | The same for the App Store (later, DEC-002) | Later |
| `data_safety.md` | Google Play Data safety answers, App Store privacy label mapping, and the data inventory they come from | Nathan + lawyer verify, then Nathan types answers into the console |
| `privacy_policy_DRAFT.md` | Privacy policy draft | LAWYER REVIEW, then host at a public URL |
| `terms_of_service_DRAFT.md` | Terms of use draft | LAWYER REVIEW |
| `content_rating_notes.md` | Content rating questionnaire notes, target audience | Nathan answers the questionnaires |
| `trademark_checklist.md` | Name clearance steps for Mulligan Hills, fallback Home Links | Nathan + IP lawyer |
| `release_checklist.md` | Ordered launch checklist | Nathan, then tick as done |
| `tester_recruitment_plan.md` | How to get 12 closed testers for 14 days | Nathan, start early |
| `open_questions.md` | Everything I need decided | Nathan |
| `web/delete-account.html` | Web page for account deletion (Play requires a web path, DEC-031) | Host it, fill 2 placeholders |

Order of work that matters: (1) trademark check, because the package id and the name cannot change after upload; (2) Play developer account, because the 12 testers x 14 days clock starts only when testing starts and is the longest wait; (3) lawyer review of the two legal drafts, which must be live before the first closed test is submitted for review (a privacy policy URL is required for the store listing).
Backend that the privacy answers describe: `supabase/README.md`.
