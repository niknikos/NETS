---
name: nets-release-check
description: Check an EAF-Nansen survey synthesis before it is sent to a regional body — scan the source and rendered output for precise positions, evidence from areas not cleared for that body, sensitive or unverified evidence, typed-in numbers and draft markings, and write a release-check report. Works for a synthesis of one survey or several. Use before any synthesis leaves the user's hands, and whenever the user asks "is this ready to send?".
---

# Release check

```bash
Rscript "<nets_path>/scripts/nets_release_check.R" "<dir>" <BODY> \
  "<dir>/outputs/<BODY>/<file>.qmd" "<dir>/outputs/<BODY>/<file>.docx"
```

`<dir>` is the survey folder, or the synthesis project folder
(`<workspace>/_syntheses/<name>`) for a synthesis of several surveys. Check the `.qmd`
(traces evidence ids and typed numbers) **and** the rendered file (what the body will
actually receive; `.docx`, `.html`, `.pdf` and `.md` are supported). The report is written
to `outputs/<BODY>/release-check.md`; the exit status is 1 on any FAIL.

## Reading the result

| Finding | What to do |
|---|---|
| FAIL coordinates | Remove or coarsen to whole degrees (or the resolution agreed for this body). |
| FAIL clearance | Remove the values for the uncleared area, including totals and cross-survey values derived from them. Do not rephrase them into relative terms. If the user says clearance has been given, they update `survey.yaml` first. |
| FAIL sensitivity | Remove, or aggregate and have the user re-classify the entry with the data owner. Values derived from sensitive entries count as sensitive. |
| FAIL evidence | Add the missing entry to the log, or remove the reference. In a synthesis of several surveys, write ids as `<survey_id>/E###`. |
| FAIL context policy | A survey is `local-only`: the draft must not come from a cloud model. Stop and tell the user. |
| WARN verification | Ask the user to check the listed entries against the originals and fill `verified_by`. |
| WARN hard-coded numbers | Replace with evidence-log values, or confirm each with the user (dates, counts of stations, etc. can be legitimate). |
| WARN uncleared area named | Confirm that only non-result mentions remain (e.g. "results pending"). |
| WARN markings / report status / deadline | Confirm with the user. |

Re-run until there is no FAIL and every WARN is explained.

## Limits — say these to the user

The check is a safety net. It cannot judge whether interpretations are sound, whether a
figure reveals positions, or whether a sentence discloses something indirectly. It does
not replace the responsible scientist's reading. **Never send, upload or submit the
synthesis yourself.**
