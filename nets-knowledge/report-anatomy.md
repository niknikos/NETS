# Reading an EAF-Nansen survey report

How to find what a synthesis needs in the redacted context copy (`context/<doc>.md`) without
reading everything, and the traps that cause wrong numbers.

## Navigate with the index first

`context/<doc>.index.md` lists headings and table/figure captions per PDF page, and marks
pages that are withheld or have no text layer. Read it, decide which pages you need, and
read only those page ranges of `context/<doc>.md`. This keeps less material in context
and makes citations exact.

## Where things usually are

Structure varies between years, regions and languages; use this as a first guess only.

| Synthesis needs | Usually in |
|---|---|
| Objectives, partners, period, area | Summary; Introduction (objectives, participation, narrative) |
| Effort (stations, transect miles, days) | Introduction or Methods: a survey-effort table |
| Methods and changes to them | Methods: acoustics (equipment, calibration, target strength), trawling (gear, tow duration), biological sampling, hydrography |
| Biomass / abundance results | Results, by region or country: tables per species or group, often with length distributions |
| Uncertainty | Methods or results tables (CVs, confidence intervals); often absent in older reports |
| Environment | Hydrography chapter: temperature, salinity, oxygen sections and maps |
| Comparison with earlier surveys | Discussion |
| Station records, positions, catch per station | **Annexes** — normally withheld by NETS; never needed at station level |

Headings in French and Portuguese reports: *Résumé / Sumário*, *Introduction / Introdução*,
*Méthodes / Métodos*, *Résultats / Resultados*, *Discussion / Discussão*, *Annexe / Anexo*,
*Tableau / Tabela*, *Figure / Figura*.

## Traps

- **Page numbers.** NETS pages are PDF page indices; the printed page number is often
  different. The evidence log records the PDF index; add the printed number in `notes` if
  the body needs it.
- **Garbled tables.** Text extraction can shift columns, merge cells or split a table
  across pages. Read the column header and the row label together, and check totals against
  the sum of rows. Anything you cannot reconcile goes in the log with a note, not into text.
- **Number formats.** French and Portuguese reports use a space or point as thousands
  separator and a comma as decimal mark ("412 000", "0,21"). Record the value in plain
  numeric form in the log and the original notation in `notes` if there is any doubt.
- **Units.** Tonnes vs thousand tonnes; numbers vs millions; kg per nautical mile squared
  vs per hour. Units often sit only in the caption.
- **Groups vs species.** Acoustic results may be reported for groups ("clupeids",
  "carangids", "other pelagics") and only partly split to species. Do not treat a group
  value as a species value.
- **Totals.** Regional totals can overlap or exclude areas; national totals can differ from
  the sum of strata when some strata were not surveyed. Say which.
- **[COORD] and withheld pages.** A masked position or a withheld page is intentional.
  Do not try to reconstruct it from context, and do not ask the user to paste it in.
- **Scanned pages.** Pages marked "no text" need OCR (`--ocr`) or the user's own reading.

## Reconciling with StoX outputs

When both a report and StoX outputs exist, they can disagree because the StoX project was
rerun after the report (new calibration, corrected data, different settings). Do not
silently prefer either: log both, note the difference and ask the user which is
authoritative for this body. See [`stox-outputs.md`](stox-outputs.md).
