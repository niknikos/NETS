# Evidence standards for syntheses

A synthesis for a regional body is read by scientists who will use it in assessments and
advice. Its authority comes from being traceable, honest about uncertainty and careful in
interpretation. These standards say how NETS achieves that.

## 1. Every number has an evidence entry

- Values enter the synthesis through `evidence/evidence-log.csv` (schema in
  `scripts/nets_evidence.R`) and are written into the `.qmd` with inline R, e.g. the value
  and its citation for an entry `E012`. The model never types a number into prose.
- `evidence_class`:
  - `reported` — exactly as the report or StoX output gives it, with document, PDF page and
    table/figure.
  - `derived` — anything you calculated (a sum, a ratio, a change since a previous survey).
    Record the formula and the source ids in `derivation`, and do the calculation in R in the
    `.qmd` or in the log, not in your head.
  - `computed` — values NETS calculated locally from haul data (e.g. IMR Biotic) or StoX
    outputs, when the published figures cannot be used as they are (e.g. catch rates with
    inconsistent units). `source_type` is `haul_data` or `stox`; `source_doc` names the
    aggregate file the computation wrote; `derivation` names the method and the script.
    Only aggregates enter the log. Verifying a computed value means reviewing the method and
    re-running or spot-checking the script, since there is no page to check it against.
- `verified_by` stays empty until **a person** has checked the entry against the original
  PDF or StoX output. The release check warns on every unverified entry used. Extraction
  errors are the most likely failure of this whole workflow; this is the control for them.
- Once verification has started, edit the log in place and never regenerate it: a rebuild
  can silently undo a person's corrections, and there is no history to recover them from.
- Prefer fewer, well-chosen numbers. A body needs the values it will use, not the report.

## 2. Keep evidence and interpretation apart

- "What the survey found" contains only what the evidence shows.
- "Interpretation" contains reasoning, and says so: *"One reading of this is…"*,
  *"This is consistent with…, although…"*.
- Give alternative explanations where they exist. A lower acoustic biomass can reflect a
  real decline, a distribution shift outside the surveyed area, different timing relative
  to migration, different coverage, or changed equipment or target strength. Say which of
  these can be excluded and on what grounds.

## 3. State uncertainty plainly

- Report the precision the source gives (CV, confidence interval, number of stations or
  hauls). If none was reported, say "no measure of precision was reported".
- Round to meaningful precision (typically two or three significant figures for biomass).
- Use calibrated language, and do not strengthen claims beyond the evidence:

| Situation | Wording |
|---|---|
| Direct measurement, adequate precision | "The survey estimated…" |
| Consistent pattern, some caveats | "The results indicate…" |
| Pattern plausible but weakly supported | "The results may suggest…, but…" |
| Not assessable from these data | "The survey cannot show whether…" |

Avoid "clearly", "dramatic", "collapse", "healthy" and similar words unless the source
itself establishes them.

## 4. Comparability checklist

Before a value is offered as a continuation of a time series, record in the synthesis
whether any of the following changed since the previous survey used by the body: vessel;
acoustic equipment, frequencies, calibration; target-strength relationships; trawl gear
and tow procedure; timing; spatial and depth coverage; species identification and grouping;
estimation method or software. If a change is known, say what it may do to the index
(direction and approximate size, if known). If comparability is unknown, say so.

## 5. Limitations are information

A clear limitations section helps the body use the results correctly. Include coverage
gaps, weather or technical interruptions, low sample sizes for particular species or
strata, and any values you could not reconcile.

## 6. Register for regional bodies

- Open with context: which survey, why it is relevant to this body and agenda item.
- Explain reasoning, not only conclusions; explain consequences for the body's work.
- Make any request to the body explicit and modest, and invite discussion rather than
  presuming agreement.
- Be respectful of all partners. Criticism, where needed, is of methods, data or
  assumptions, never of people or institutions.
- Write in the body's working language as recorded in `survey.yaml` (`language`); for a
  bilingual body, ask the user which version is needed.
