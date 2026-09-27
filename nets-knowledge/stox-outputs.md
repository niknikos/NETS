# Using StoX project outputs

StoX is IMR's software for acoustic and swept-area survey estimation. EAF-Nansen surveys
increasingly use it for biomass and abundance estimates, including bootstrap-based
uncertainty. NETS reads StoX **outputs**, never the raw input data.

> **Verify against your projects.** Output layout and table names differ between StoX 2.7
> (Java-based) and StoX 3.x (R-based, RstoxFramework), and with how each project was set up.
> NETS therefore discovers tables instead of assuming names. Confirm with the project owner
> which process produced the published estimate.

## Layout (typical)

- **StoX 3.x:** `<project>/output/<baseline|analysis|report>/<ProcessName>/…` with
  tab-separated `.txt` tables, and sometimes `.rds`/`.RData` objects.
- **StoX 2.7:** `<project>/output/baseline/data/…` and `<project>/output/r/{data,report}/…`,
  mostly tab-separated `.txt`.
- `input/` holds raw biotic and acoustic data. NETS ignores it entirely.

Put either the whole project or a copy of its `output/` folder under `sources/stox/`.

## Workflow

1. **Inventory** (structure only, no values):
   ```bash
   Rscript "<nets_path>/scripts/nets_stox.R" inventory "<survey_dir>"
   ```
   Read `context/stox-inventory.md`. Each table is `detail` (has coordinates or
   station/haul/EDSU/PSU/individual/sample identifiers) or `aggregate`.
2. **Choose the tables** that hold the estimate the body needs. Typically these are report
   tables summarising bootstrap results by stratum, species category and length (or age)
   group. Ask the user when several candidates exist.
3. **Bring aggregates into context**:
   ```r
   source(file.path(nets_path, "scripts", "nets_stox.R"))
   # an aggregate table, filtered
   nets_stox_export(file, survey_dir, "bootstrap_sardinella", SpeciesCategory == "<species>")
   # a detail table, summed to coarser groups (grouping by station/haul/position is refused)
   nets_stox_summarise(file, survey_dir, "biomass_by_stratum",
                       group_by = c("Stratum", "SpeciesCategory"),
                       sum_cols = c("Abundance", "Biomass"))
   ```
   Results go to `context/stox-summaries/<name>.csv` with a provenance note. Only these files
   are read by the agent.
4. **Log the values used** in the evidence log with `source_type = stox`, the output file as
   `source_doc` and the process/table name as `locator`.

## Rules

- Never print a detail table (or its `head()`) to the console: console output enters the
  agent's context. Work with `names()`, `nrow()` and aggregates.
- Only additive quantities (abundance, biomass) may be summed. Means, CVs and percentiles
  from bootstrap reports cannot be summed or averaged across groups; use the report table at
  the level it was produced, or ask the project owner to run the report at the needed level.
- Record the StoX version and project date if known (ask the user); estimates change when
  projects are rerun.
- If StoX results and the printed report differ, log both and ask which is authoritative
  (see [`report-anatomy.md`](report-anatomy.md)).
