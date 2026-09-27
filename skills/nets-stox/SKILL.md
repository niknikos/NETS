---
name: nets-stox
description: Use StoX project outputs (StoX 2.7 or 3.x) behind an EAF-Nansen survey report in a NETS synthesis — inventory output tables without reading values, classify them as detail or aggregate, and export or summarise only aggregates (by stratum, area, species, length group) for the agent. Use when the user has StoX projects or outputs for a survey, or asks for biomass/abundance estimates with uncertainty from StoX.
---

# Bring StoX outputs into a synthesis

Background and rules: [`../../nets-knowledge/stox-outputs.md`](../../nets-knowledge/stox-outputs.md).
Honour the survey's `context_policy` (even `aggregates-only` allows StoX summaries;
`local-only` allows none).

1. **Inventory** — structure only:
   ```bash
   Rscript "<nets_path>/scripts/nets_stox.R" inventory "<survey_dir>"
   ```
   Read `context/stox-inventory.md`.
2. **Agree with the user which tables hold the estimates** the body needs (e.g. the
   bootstrap report by stratum, species category and length). Ask which StoX version and
   project run produced the published estimate.
3. **Export or summarise** into `context/stox-summaries/` from R:
   ```r
   nets_path <- jsonlite::read_json("~/.nets/config.json")$nets_path   # USERPROFILE on Windows
   source(file.path(nets_path, "scripts", "nets_stox.R"))
   nets_stox_export(file, survey_dir, "<name>", <optional filters>)                    # aggregate tables
   nets_stox_summarise(file, survey_dir, "<name>", group_by = c(...), sum_cols = c(...))  # detail tables
   ```
   Grouping by station, haul, EDSU, PSU, individual or position columns is refused by
   design. Sum only additive quantities; never sum or average CVs or percentiles.
4. **Read only the summaries.** Never print detail tables to the console.
5. **Reconcile** with the report tables where both exist. Log differences instead of
   choosing silently, and ask which source is authoritative.
6. **Log the values used** in `evidence/evidence-log.csv` with `source_type = stox`, the
   output file as `source_doc` and process/table as `locator`. Values read from a StoX
   output table are `reported`; values you summarised or recomputed from StoX (or from
   haul data) are `computed`, with the method and script in `derivation`; values
   calculated from other log entries are `derived`.
