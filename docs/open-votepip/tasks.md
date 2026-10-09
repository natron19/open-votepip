# VotePIP Demo - Build Tracker

**Spec:** [`votepip-demo-spec.md`](votepip-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh votepip "VotePIP" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)`, layout fallback name, accent CSS, landing page | `[x]` |
| 2 | Models: `Proposal`, `ClarityCheck` migrations, validations, constants, associations | `[x]` |
| 3 | Routes and controllers: `ProposalsController` CRUD, `ClarityChecksController` (rate limit, rescues) | `[x]` |
| 4 | Views and Stimulus: dashboard, form, proposal page, result page, `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `votepip_motion_v1` prompt, parser, `PersonNameCheck` | `[x]` |
| 6 | Seeds: template, Willowbend example proposal with a completed check, `demo_placeholder_v1` removed | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml`, `evals/cases/votepip_motion_v1.yml` (8 cases), placeholder case removed | `[x]` |
| 8 | Specs: models, `PersonNameCheck`, requests; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3124), pre-publish check, local commit | `[x]` |

## Quick reference

```
proposals_path                          GET  /proposals   (also /dashboard)
new_proposal_path                       GET  /proposals/new
proposal_path(p)                        GET  /proposals/:id
edit_proposal_path(p)                   GET  /proposals/:id/edit
proposal_clarity_checks_path(p)         POST /proposals/:id/checks
proposal_clarity_check_path(p, c)       GET  /proposals/:id/checks/:id
```

```
Template:   votepip_motion_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.3)
Variables:  title, body, problem, decider, deadline_or_cost
JSON:       single_proposal, votable, verdict_line, rewritten_motion,
            reader_questions[0-4], suggested_edits[2], split_into[2-4] when bundled
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-votepip` (real Gemini calls).
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
