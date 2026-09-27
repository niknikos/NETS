---
name: nets-release-check
description: Check an EAF-Nansen survey synthesis or slide deck before it is sent to a regional body — scan the source and every rendered file (Word, HTML, PowerPoint, PDF) for precise positions, evidence from areas not cleared for that body, sensitive or unverified evidence, country names in forms to avoid, sensitive place names not agreed with the data owners, typed-in numbers and draft markings, and write a release-check report. Use before anything leaves the user's hands, and whenever the user asks "is this ready to send?".
---

# Release check

```bash
Rscript "<nets_path>/scripts/nets_release_check.R" "<dir>" <BODY> \
  "<dir>/outputs/<BODY>/<file>.qmd" "<dir>/outputs/<BODY>/<file>.docx" "<dir>/outputs/<BODY>/<file>.html"
```

`<dir>` is the survey folder, or the synthesis project folder
(`<workspace>/_syntheses/<name>`) for a synthesis of several surveys. Check the `.qmd`
(traces evidence ids and typed numbers) **and** every rendered file the body will receive:
`.docx`, `.html` (documents and reveal.js decks), `.pptx`, `.pdf` and `.md` are supported.
The report is written to `outputs/<BODY>/release-check.md`; the exit status is 1 on any
FAIL.

## Reading the result

| Finding | What to do |
|---|---|
| FAIL coordinates | Remove or coarsen to whole degrees (or the resolution agreed for this body). |
| FAIL clearance | Remove the values for the uncleared area, including totals and cross-survey values derived from them. Do not rephrase them into relative terms. If the user says clearance has been given, they update `survey.yaml` first. |
| FAIL sensitivity | Remove, or aggregate and have the user re-classify the entry with the data owner. Values derived from sensitive entries count as sensitive. |
| FAIL evidence | Add the missing entry to the log, or remove the reference. In a synthesis of several surveys, write ids as `<survey_id>/E###`. |
| FAIL context policy | A survey is `local-only`: the draft must not come from a cloud model. Stop and tell the user. |
| FAIL naming | A form of a country name to avoid (e.g. "Ivory Coast"). Use the form given. |
| FAIL sensitive name | A disputed or sensitive place name. Use it only in wording the data owners have agreed, recorded by the user under `naming.agreed_terms` in `survey.yaml` (or `synthesis.yaml`). Never choose the wording yourself. |
| WARN naming | A form to check (e.g. "Gambia" without its article), or an area in `survey.yaml` named differently from the register in `nets-knowledge/country-names.yaml`. |
| WARN scope | A value from an area outside the project's `areas`, or a whole-survey value of a survey that reaches beyond them. Remove it, or confirm it only describes the survey (dates, methods). |
| WARN verification | Ask the user to check the listed entries against the originals and fill `verified_by`. |
| WARN hard-coded numbers | Replace with evidence-log values, or confirm each with the user (dates, counts of stations, etc. can be legitimate). |
| WARN uncleared area named | Confirm that only non-result mentions remain (e.g. "results pending"). |
| WARN markings / report status / deadline | Confirm with the user. |

Re-run until there is no FAIL and every WARN is explained.

## Limits — say these to the user

The check is a safety net. It cannot judge whether interpretations are sound, whether a
figure reveals positions, or whether a sentence discloses something indirectly. Text inside
images (maps, charts) is not read. The country register was written from general
knowledge and is only as good as its last review by programme staff. It does not replace
the responsible scientist's reading. **Never send, upload or submit the synthesis
yourself.**
