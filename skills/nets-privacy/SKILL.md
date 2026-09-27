---
name: nets-privacy
description: Rules for handling confidential EAF-Nansen survey material with an AI agent — data ownership and clearance per coastal state and reporting body, what may enter the agent's context, context policies (standard / aggregates-only / local-only), sensitive positions and VMEs, and what may leave the machine. Use for privacy or data-sharing questions and whenever a synthesis touches uncleared or sensitive material.
---

# Handling survey material safely

The full reasoning is in
[`../../nets-knowledge/data-governance.md`](../../nets-knowledge/data-governance.md). This
skill is the operational summary.

## Before reading anything from a survey

1. Read `survey.yaml` in the survey folder. Note `report_status`, `context_policy`, the
   areas and their owners, `sensitive_items`, and clearance for the target body.
2. Check `~/.nets/config.json`: if `privacy_onboarded_at` exists, do not re-gate routine work
   on a new confirmation. If `data_agreements_confirmed` is `false`, treat every survey as
   at least `aggregates-only` unless its manifest has been explicitly set otherwise by the
   user after clarification.
3. Apply the context policy:
   - `standard`: read `context/` (redacted) and `evidence/`.
   - `aggregates-only`: read only `context/*.index.md`, `context/stox-inventory.md` and
     `context/stox-summaries/`. Ask the user for narrative points.
   - `local-only`: do not read `context/` or `evidence/`; do not draft the synthesis. Offer
     structure, workflow help and wording guidance that contains no survey content.

## Always

- **Never open `sources/` or `local/`.** Originals and unredacted text are for the user and
  for NETS scripts only.
- **Never reconstruct what redaction removed** (`[COORD]`, withheld pages), and do not ask
  the user to paste it in.
- **Never print detail tables to the console** when running R (`head()`, `print()`, `View()`
  of station- or individual-level data): console output enters your context.
- **Never include results for an area not cleared for the target body**, including totals
  that contain it and comparisons that reveal it. In a synthesis of several surveys this
  holds per survey: an area cleared in one survey may still be pending in another.
- **Name countries and places as agreed.** Use the area names in `survey.yaml`; for
  disputed or sensitive places (listed in
  [`../../nets-knowledge/country-names.yaml`](../../nets-knowledge/country-names.yaml)) use
  only wording the user has recorded under `naming.agreed_terms`, never your own choice.
- **Never send, upload or submit** anything. You prepare drafts and checks; the responsible
  scientist decides and sends through the proper channel.
- **Never commit survey material** to NETS, BAIT or any project repository.
- Keep survey material out of web searches, issue trackers and other tools.
- **Never ask for, accept or handle credentials** (ResourceSpace keys, passwords). The user
  stores them in the OS credential store themselves; if they paste one into chat, tell them
  to revoke and replace it.

## Ask the user first when

- a synthesis would give positions or maps finer than whole degrees, or anything about VME
  indicator taxa, dense aggregations or fishing-vessel sightings;
- an area's status is `pending` or missing but the user asks to include it (explain the
  consequence; they may update `survey.yaml` if clearance has in fact been given);
- material touches disputed boundaries, shared-stock negotiations or third-party data;
- anything is listed under `sensitive_items`.

## Reminders, not repeated gates

Give a brief reminder about training/retention only when it adds value: first NETS task in
a long while, the user asks about privacy, or unusually sensitive material is involved.

## If something leaks

Stop, tell the user exactly what went where, and help them follow the programme's and
institute's procedures. Say plainly that data sent to an external service may persist.
