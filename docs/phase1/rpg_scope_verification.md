# Golfer/club RPG scope: independent review

Verifier: separate agent `/root/verify_session`, 5 October 2026. Reviewed `rpg_scope.md`, changed research/progression text and pending Decisions section J against available repository sources. No implementation edits or runtime checks.

## Disposition

Intent is represented accurately: create/control/train a golfer, play the built course and competitions, NPC private matches, celebrity home/VIP progression, wildlife, hired/placed staff, personal/delegated maintenance, humour, and visible trophy/appearance rewards. PROP-11–14 openly propose launch/campaign amendments. DEC-014/039 remain unchanged; section J is explicitly pending, not locked. The design parameters and milestones are proposals, not implemented features or an approved new schedule. No runtime or completion certification is granted.

No remaining concrete documentary blocker found after these two issues were corrected and the revised text was independently read:

1. The research document's final playtest paragraph now prioritizes a controllable player-built hole, attribute training, a rival match and a visible reward, with course diagnosis/briefs/readiness alongside that core loop. The earlier optional-minigame priority no longer contradicts the clarified intent.
2. Inventory evidence is now qualified. `rpg_scope.md` names the lead-inspected full phase1 tree `999ac8a746ee620dfb0c23769ab9661a56931dcf` and states that art/terrain/character/render/input paths are absent from this partial checkout. Their capabilities are explicitly status-documented foundations, not newly inspected implementation or runtime evidence. This verifier checked that disclosure; it did not independently retrieve the remote tree or inspect those absent implementations.

## Verified capability boundaries

- `MHShotSim` is a prototype with Q16.16 metre positions and skill 0..100; rating `MHRSim` uses centiyards and skill 0..1000. Neither is an implemented human aiming/power/career interface. Rating putting is probabilistic.
- `MHTournamentSim.run_field` accepts deterministic field context, simulates all entrants, and exposes no personally played round input. Personal tournament participation and rival matches need explicit integration and resume/settlement rules.
- Club levels/stats/achievements, building-tier gates, VIP/celebrity/wildlife event-card content, and plaque/flag/cart-paint unlock IDs exist. They do not establish personal attributes, persistent homebuyer identity, staff assignments, visible animals, interactive grounds maintenance, or applied trophy/building appearances.
- The live session deliberately lacks authoritative staff/pace and a finished playable scene/save connection. The current pooled economy timing validates only the modeled building/course path, not the proposed RPG campaign, wages/prizes or active golf time.

Proposed integer/seeded gameplay, once-only rewards, finite homes, procedural art, fictional people, cash-only NPC stakes, pause policy, save migration and separate ownership/selection rules are consistent with existing boundaries. New scope must be locked explicitly and implemented/tested before any playable or completion claim. Source links in the original research were not rechecked during this scope-only review.
