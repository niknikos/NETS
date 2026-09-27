---
name: nets-synthesis
description: Prepare a synthesis of an EAF-Nansen survey (reports and/or StoX outputs) for a regional body — CECAF (Scientific Sub-Committee or working groups), SEAFO, SIOFA, BCC or SWIOFC — with every number traced to a verified evidence log, evidence kept apart from interpretation, uncertainty and comparability stated, and clearance per country respected. Use when the user asks to report, summarise or synthesise survey results for one of these bodies or a similar meeting.
---

# Prepare a synthesis for a regional body

A synthesis helps a body use survey results correctly. It should be traceable, honest about
uncertainty, and respectful of each data owner's decisions. Read
[`../../nets-knowledge/evidence-standards.md`](../../nets-knowledge/evidence-standards.md)
before drafting.

## 0. Preconditions (stop if any fails)

1. `survey.yaml` exists and has a `reporting` entry for the body, with clearance per area.
   If not, help the user complete it ([`../nets-ingest/SKILL.md`](../nets-ingest/SKILL.md)).
2. `context_policy` is not `local-only`. If it is, explain why you cannot draft, and offer
   structure and wording guidance free of survey content.
3. Apply [`../nets-privacy/SKILL.md`](../nets-privacy/SKILL.md) throughout.

## 1. Establish the brief with the user

- The body, the meeting and agenda item or terms of reference, and the deadline.
- What the body is asked to do with the results (note, use in an assessment, advise).
- Which stocks, species groups or ecosystem themes matter to it. Read the body profile in
  `../../nets-knowledge/bodies/<body>.md` and its "Programme notes"; raise any unchecked
  "Verify before use" item that matters for this submission.
- Language, length, and whether a body template must be used.
- Which areas are cleared. Say plainly which results **cannot** be included.

## 2. Build the evidence

- Read report pages via the index (policy permitting) and StoX summaries
  ([`../nets-stox/SKILL.md`](../nets-stox/SKILL.md)).
- Log each value you may use in `evidence/evidence-log.csv`: exact source, page, table,
  uncertainty, `area_id`, sensitivity. Calculate derived values in R and record the
  derivation.
- Also log the facts needed for the comparability checklist (vessel, gear, acoustic
  equipment, timing, coverage, method), even when qualitative.
- **Ask the user to verify** the entries against the originals and to fill `verified_by`.
  Offer a short list sorted by importance so the checking is manageable.

## 3. Draft

```bash
Rscript "<nets_path>/scripts/nets_new_synthesis.R" "<survey_dir>" <BODY> "<author>"
```

This creates `outputs/<BODY>/<survey>_<BODY>_synthesis.qmd` from the template. Then:

- Every number via inline R from the evidence log (value and citation); add each id to
  `used_ids` for the annex. Never type a value.
- **What the survey found**: evidence only. **Interpretation**: reasoning, labelled, with
  alternatives. **Limitations and comparability**: specific, with consequences for the
  body's use. **Implications** and **Points for consideration**: modest, explicit, and
  inviting discussion.
- Follow the body profile's emphasis and the register in evidence-standards (context first,
  reasoning explained, consequences stated, no overstatement, no promotional language).
- Only cleared areas. Whole-survey totals only when all constituent areas are cleared.
- Positions at whole-degree resolution at most, unless the user has agreed otherwise for
  this body (see the body profile's sensitivity notes).

Render when Quarto is available (`quarto render <file>.qmd --to docx` or `--to html`);
otherwise leave the `.qmd` for the user to render.

## 4. Check and hand over

Run [`../nets-release-check/SKILL.md`](../nets-release-check/SKILL.md) on the `.qmd` **and**
the rendered file. Resolve every FAIL. Then summarise for the user:

- what the synthesis says in three or four sentences;
- which areas are included and which are not, and why;
- unverified evidence entries, open "Verify before use" items and judgement calls you made;
- that sending it is their decision, through the body's normal channel.

## Learning loop

If the work produced something reusable (a pattern for a body's index tables, a reliable
way to read a report series' biomass tables), offer to save it as a recipe in
`cookbook/` (copy `cookbook/_TEMPLATE.md`; code and prose only, never survey values).
Offer also to update the body profile's "Programme notes" with confirmed, non-confidential
facts (deadlines, formats, subsidiary body names).
