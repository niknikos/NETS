---
name: nets-ingest
description: Register an EAF-Nansen survey in the NETS workspace and prepare its report PDFs for an AI agent — create the survey folder, fill survey.yaml (areas, data owners, clearance per reporting body, sensitivity), extract text locally, mask positions and withhold station listings, and review the redaction. Use when the user has new survey reports (PDF) to work with, or asks to "add", "load" or "read" a Nansen survey report.
---

# Register a survey and ingest its reports

Paths: `nets_path` and `workspace_path` come from `~/.nets/config.json`. If there is no
config, run [`../nets-install/SKILL.md`](../nets-install/SKILL.md) first.

## 1. Create the survey folder

```bash
Rscript "<nets_path>/scripts/nets_new_survey.R" "<survey_id>"
```

Use the programme's survey or cruise identifier. This creates
`<workspace>/<survey_id>/` with `survey.yaml`, the folder structure and
`AGENT-READ-POLICY.md` (what you may and may not read there).

## 2. Fill in `survey.yaml` with the user

Work through it together; do not guess ownership or clearance.

- `areas`: one entry per EEZ, joint zone or high-seas area, with the data owner and any
  aliases (French/Portuguese names) the release check should recognise.
- `reporting`: one block per body the user will report to, with the meeting, due date,
  language and **clearance per area** (`cleared` / `pending` / `refused` / `not_required`
  with a scope note). Record who cleared and when.
- `report_status`, `context_policy`, `sensitive_items`.
- `redaction`: leave defaults unless the user knows annex pages to withhold.

Ask directly when anything is unknown: *"Has Mauritania cleared these results for the
CECAF working group, or is that still pending?"* Leaving an area `pending` is safe.

## 3. Add the sources

Either the user copies the report PDFs into `sources/reports/` and any StoX projects (or
their `output/` folders) into `sources/stox/`, or NETS fetches them from a ResourceSpace
collection (below). Either way, **do not open them**.

### From ResourceSpace (e.g. IMR's document archive)

Works only from a machine inside the institute's network, with the connection set up once
(nets-install Step 5b). **Never ask the user for a password or API key, and never accept
one in chat**; if they offer it, stop them and point to `keyring::key_set()` in their own R
console. The collection number is in the collection's address (`!collection124` → 124).

```bash
Rscript "<nets_path>/scripts/nets_fetch_resourcespace.R" "<survey_dir>" --collection 124 --list
Rscript "<nets_path>/scripts/nets_fetch_resourcespace.R" "<survey_dir>" --collection 124
```

Run `--list` first and confirm with the user which resources belong to this survey (a
collection may hold several surveys); then download only those with `--refs 101,102`. PDFs go to `sources/reports/`, zip files (with
`--ext pdf,zip`) to `sources/stox/`; `sources/resourcespace.csv` records what came from
where. If the listing works but downloads fail, the server may restrict direct file access
for API users: ask the user to check with the ResourceSpace administrators.

## 4. Extract and redact (local)

```bash
Rscript "<nets_path>/scripts/nets_ingest_pdf.R" "<workspace>/<survey_id>"      # add --ocr for scanned pages
```

The script prints counts only. It writes the unredacted text to `local/` (never read it),
the redacted copy and a page index to `context/`, a per-page log to
`context/redaction-log.csv`, and checksums to `sources/register.csv`.

## 5. Review the redaction with the user

Read `context/redaction-log.csv` (counts only) and `context/<doc>.index.md`, then tell the
user:

- which pages were withheld and why (e.g. "pp. 45–60, station listings"), and pages without
  a text layer;
- that masking is pattern-based and can miss unusual notations — ask them to glance at the
  withheld/kept decisions in the index and, if they wish, at `context/<doc>.md` themselves.

If they want pages withheld or released, update `redaction.withhold_pages` /
`release_pages` in `survey.yaml` and re-run with `--force`.

## 6. Reading strategy (when the context policy allows)

Read the index first, then only the page ranges you need from `context/<doc>.md`
(see [`../../nets-knowledge/report-anatomy.md`](../../nets-knowledge/report-anatomy.md)).
Record every value you intend to use in `evidence/evidence-log.csv` as you go (schema in
`scripts/nets_evidence.R`), with `entered_by = agent` and `verified_by` empty.

Next: StoX outputs with [`../nets-stox/SKILL.md`](../nets-stox/SKILL.md), or the synthesis
with [`../nets-synthesis/SKILL.md`](../nets-synthesis/SKILL.md).
