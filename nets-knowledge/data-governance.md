# Data governance: ownership, clearance and sensitivity

Read this before any synthesis. It explains *why* NETS handles survey material the way it
does, so that you can apply the rules sensibly to cases they do not spell out.

## Why this matters

EAF-Nansen surveys are carried out at the request of, and in partnership with, coastal
states and regional organisations. Results from national waters are, in practice, the
partner country's results: they inform national management, and some touch on questions
that are commercially or politically delicate (shared stocks, allocation negotiations,
boundary areas). The programme's credibility with partners rests on handling their results
exactly as agreed. A synthesis that releases a country's results to a regional body before
that country has agreed does real damage, even when the numbers are correct.

**Confirm the specific terms for each survey.** The programme's data policy, the survey
agreement and any national rules decide what may be shared, with whom and when. NETS
records the outcome in `survey.yaml`; it does not decide it.

## Clearance

- Clearance is recorded **per reporting body and per area** in `survey.yaml`
  (`reporting.<BODY>.clearance.<area_id>`), with who cleared it, when, and its scope.
- `cleared` — the data owner agreed to this use, within the recorded scope.
- `pending` / missing — not yet agreed. **No results for that area may appear**, not even
  rounded, relative ("higher than last year") or implied by subtraction from a total.
- `refused` — as pending, and do not ask the agent to find a way around it.
- `not_required` — e.g. high-seas results where the programme itself decides; always with a
  scope note explaining the basis.
- Whole-survey totals that include uncleared areas are themselves uncleared.
- A body's meeting report is usually a public document. **Treat submission as
  publication.**

## Sensitivity tiers

| Tier | Examples | Agent context | In outputs |
|---|---|---|---|
| Public | Published reports, cleared and published syntheses | yes | yes |
| Restricted | Unpublished report text and summary tables; StoX aggregates (stratum, region, length group) | yes, redacted copies only, under the onboarding conditions below | only for areas cleared for that body |
| Sensitive | Station positions and station-level catches; individual records; EDSU/track-level acoustic data; positions of VME indicator taxa, spawning or dense aggregations; fishing-vessel sightings; anything listed under `sensitive_items` | **no** — local scripts only, output as aggregates | only aggregated, and only after asking the user |

"Sensitive" also covers things that are not coordinates: identities of fishing vessels
observed during a survey, results in areas whose boundaries are disputed, and data
contributed by third parties (national vessels, observers) under their own terms. When
naming a disputed or contested area, use the data owner's own terminology and ask.

## Naming countries and places

How a country or territory is named is itself read as a position. NETS keeps a register of
country names (English, French, Portuguese), forms to avoid and sensitive place names in
[`country-names.yaml`](country-names.yaml). Each survey's `survey.yaml` names its areas
(that is what a synthesis prints) and records under `naming.agreed_terms` any wording the
data owners have agreed for a sensitive place. The release check fails a synthesis that
uses a form marked "fail" or a sensitive name without agreed wording. The register was
written from general knowledge; programme staff should confirm it and keep it current.

## Context policies (per survey)

Reading a report means its text is sent to the model provider for processing. That is
acceptable only when training and retention are switched off **and** the survey agreements
allow it. `context_policy` in `survey.yaml` records the decision:

- `standard` — the agent may read the redacted copies in `context/` and the evidence log.
- `aggregates-only` — only indexes, the StoX inventory and StoX summaries. Report text stays
  local; the user supplies the narrative points.
- `local-only` — nothing from this survey may reach a cloud model. The agent may explain the
  workflow and run scripts whose output it does not read, but it must not read `context/` or
  `evidence/` and must not draft the synthesis. Suggest a local model, or offer structure and
  wording guidance that contains no survey content.

## What must never happen

- Opening files in `sources/` or `local/` (originals and unredacted text).
- Pasting survey content into web tools, issue trackers, search engines, or any service other
  than the configured agent.
- Committing survey material to any repository (NETS, BAIT, or a project repo).
- Sending anything to a body, a secretariat or a colleague. **The agent prepares; the
  responsible scientist decides and sends.**

## Personal data

Reports list participants. Citing authors and institutions is normal; do not add contact
details or personal information beyond what the published report already states.

## If something goes wrong

Stop, tell the user plainly what was exposed and where, and help them follow the
programme's and institute's procedures. Data sent to an external service may persist after
deletion, so say so rather than implying the exposure can be undone.
