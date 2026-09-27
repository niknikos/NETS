# nets_stox.R — inventory StoX project outputs and turn them into agent-safe aggregates.
#
# Usage:
#   Rscript nets_stox.R inventory <survey_dir> [<stox_path> ...]
#
# and from R (after source("nets_stox.R")):
#   nets_stox_summarise(file, survey_dir, name, group_by, sum_cols, ...)  # detail -> aggregate
#   nets_stox_export(file, survey_dir, name, ...)                         # aggregate table -> context/
#
# StoX 2.7 and StoX 3.x lay outputs out differently, and table names vary with how a
# project was built, so tables are discovered rather than assumed. Each table is
# classified by its columns:
#   detail     has coordinates or station/haul/EDSU/PSU/individual identifiers. Never read
#              by the agent; only summarised to coarser groups.
#   aggregate  none of those columns (e.g. bootstrap reports by stratum and length group).
#              May be exported to context/ for the agent.
# Nothing in this file prints table values to the console.

if (!exists("nets_read_manifest", mode = "function")) {
  local({
    self <- NULL
    for (i in rev(seq_len(sys.nframe()))) {
      of <- sys.frame(i)$ofile
      if (!is.null(of)) { self <- of; break }
    }
    if (is.null(self)) self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
    source(file.path(dirname(normalizePath(self)), "nets_common.R"))
  })
}

nets_stox_coord_cols <- regex(
  "latitude|longitude|^lat($|_|[A-Z])|^lon(g)?($|_|[A-Z])|_lat$|_lon$|position",
  ignore_case = TRUE
)
# Whole identifier names only: StoX also has grouping variables such as
# IndividualTotalLength or IndividualAge, which are length/age classes, not identifiers.
nets_stox_unit_cols <- regex(
  paste0("^(edsu|psu|ssu|station|haul|individual|specimen|superindividual|sample|",
         "serialn(o|umber)|log|logkey|stationid|haulid)$|(station|haul|individual|specimen|edsu|sample|cruise)key$"),
  ignore_case = TRUE
)
nets_stox_data_ext <- "\\.(txt|csv|tsv|rds|rdata)$"

nets_stox_detail_cols <- function(cols) {
  cols[str_detect(cols, nets_stox_coord_cols) | str_detect(cols, nets_stox_unit_cols)]
}

# Every data file under the StoX paths given, or under <survey_dir>/sources/stox/.
nets_stox_files <- function(paths) {
  files <- unlist(map(paths, ~ list.files(.x, pattern = nets_stox_data_ext, recursive = TRUE,
                                          full.names = TRUE, ignore.case = TRUE)))
  # StoX input data (raw biotic/acoustic XML etc.) is never an output table.
  files[!str_detect(files, regex("[/\\\\]input[/\\\\]", ignore_case = TRUE))]
}

.nets_read_delim <- function(file, n_max = Inf) {
  delim <- if (str_detect(file, regex("\\.csv$", ignore_case = TRUE))) "," else "\t"
  suppressWarnings(read_delim(file, delim = delim, n_max = n_max, show_col_types = FALSE,
                              progress = FALSE, guess_max = 10000))
}

# All tables in one file, as a named list of data frames (rds/RData files can hold several).
nets_stox_tables <- function(file) {
  if (str_detect(file, regex("\\.rds$", ignore_case = TRUE))) {
    x <- readRDS(file)
  } else if (str_detect(file, regex("\\.rdata$", ignore_case = TRUE))) {
    env <- new.env()
    load(file, envir = env)
    x <- as.list(env)
  } else {
    return(list(table = .nets_read_delim(file)))
  }
  if (is.data.frame(x)) return(list(table = x))
  flat <- list()
  walk_obj <- function(obj, prefix) {
    if (is.data.frame(obj)) {
      flat[[prefix]] <<- obj
    } else if (is.list(obj)) {
      nms <- names(obj) %||% as.character(seq_along(obj))
      for (i in seq_along(obj)) walk_obj(obj[[i]], if (nzchar(prefix)) paste0(prefix, "$", nms[i]) else nms[i])
    }
  }
  walk_obj(x, "")
  flat
}

nets_stox_read <- function(file, object = NULL) {
  tabs <- nets_stox_tables(file)
  if (is.null(object)) {
    if (length(tabs) != 1) {
      stop(basename(file), " holds several tables; name one with object = (see the inventory).", call. = FALSE)
    }
    return(as_tibble(tabs[[1]]))
  }
  if (!object %in% names(tabs)) stop("No table '", object, "' in ", basename(file), call. = FALSE)
  as_tibble(tabs[[object]])
}

nets_stox_inventory <- function(survey_dir, paths = NULL) {
  paths <- paths %||% file.path(survey_dir, "sources", "stox")
  files <- nets_stox_files(paths)
  if (!length(files)) stop("No StoX output files found under: ", paste(paths, collapse = ", "), call. = FALSE)
  base <- normalizePath(file.path(survey_dir, "sources", "stox"), mustWork = FALSE)

  inv <- map_dfr(files, function(f) {
    tabs <- tryCatch(nets_stox_tables(f), error = function(e) NULL)
    if (is.null(tabs) || !length(tabs)) {
      return(tibble(file = f, object = NA_character_, rows = NA_integer_, n_cols = NA_integer_,
                    columns = "", tier = "unreadable", detail_columns = ""))
    }
    imap_dfr(tabs, function(d, nm) {
      det <- nets_stox_detail_cols(names(d))
      tibble(
        file = f, object = if (length(tabs) == 1) NA_character_ else nm,
        rows = nrow(d), n_cols = ncol(d),
        columns = paste(names(d), collapse = ", "),
        tier = if (length(det)) "detail" else "aggregate",
        detail_columns = paste(det, collapse = ", ")
      )
    })
  }) |>
    mutate(file = str_remove(normalizePath(file, mustWork = FALSE), fixed(paste0(base, .Platform$file.sep))))

  out <- file.path(survey_dir, "context", "stox-inventory.md")
  dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
  writeLines(c(
    "# StoX output inventory", "",
    paste0("Generated by NETS ", nets_version(), " on ", Sys.Date(), ". Paths are relative to sources/stox/."),
    "Table structure only \u2014 no values. `detail` tables must be summarised with",
    "`nets_stox_summarise()` before an agent sees anything from them; `aggregate` tables can",
    "be exported to context/stox-summaries/ with `nets_stox_export()`.", "",
    "| File | Object | Rows | Tier | Detail columns | Columns |", "|---|---|---:|---|---|---|",
    pmap_chr(inv, function(file, object, rows, n_cols, columns, tier, detail_columns) {
      paste0("| ", file, " | ", object %|NA|% "", " | ", rows, " | ", tier, " | ",
             detail_columns, " | ", str_trunc(columns, 300), " |")
    })
  ), out)
  message("Inventory of ", nrow(inv), " table(s) written to ", out,
          " (", sum(inv$tier == "detail"), " detail, ", sum(inv$tier == "aggregate"), " aggregate).")
  invisible(inv)
}

`%|NA|%` <- function(x, y) if (is.na(x)) y else x

.nets_stox_write <- function(d, survey_dir, name, source_file, note) {
  if (!str_detect(name, "^[A-Za-z0-9_-]+$")) stop("name must be letters, digits, - or _ only", call. = FALSE)
  det <- nets_stox_detail_cols(names(d))
  if (length(det)) stop("Output would contain detail columns: ", paste(det, collapse = ", "), call. = FALSE)
  out_dir <- file.path(survey_dir, "context", "stox-summaries")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(out_dir, paste0(name, ".csv"))
  write_csv(d, out)
  writeLines(c(paste0("source: ", source_file), paste0("created: ", Sys.time()),
               paste0("nets_version: ", nets_version()), paste0("method: ", note)),
             file.path(out_dir, paste0(name, ".provenance.txt")))
  message("Wrote ", out, " (", nrow(d), " rows x ", ncol(d), " columns).")
  invisible(out)
}

# Sum additive quantities (abundance, biomass) from a detail or aggregate table to coarser
# groups. `...` are optional dplyr filter conditions applied first. Grouping by any
# coordinate or unit-identifier column is refused.
nets_stox_summarise <- function(file, survey_dir, name, group_by, sum_cols, ..., object = NULL) {
  d <- nets_stox_read(file, object)
  forbidden <- intersect(group_by, nets_stox_detail_cols(names(d)))
  if (length(forbidden)) {
    stop("Refusing to group by station/position-level columns: ", paste(forbidden, collapse = ", "),
         ". Summarise to stratum, area, species or length group instead.", call. = FALSE)
  }
  missing <- setdiff(c(group_by, sum_cols), names(d))
  if (length(missing)) stop("Columns not in table: ", paste(missing, collapse = ", "), call. = FALSE)
  filters <- rlang::enquos(...)
  out <- d |>
    filter(!!!filters) |>
    group_by(across(all_of(group_by))) |>
    summarise(
      across(all_of(sum_cols), ~ sum(.x, na.rm = TRUE)),
      n_rows = n(),
      rows_with_missing = sum(!stats::complete.cases(pick(all_of(sum_cols)))),
      .groups = "drop"
    )
  note <- paste0("sum of ", paste(sum_cols, collapse = ", "), " by ", paste(group_by, collapse = ", "),
                 if (length(filters)) paste0("; filter: ", paste(map_chr(filters, rlang::as_label), collapse = " & ")))
  .nets_stox_write(out, survey_dir, name, file, note)
}

# Copy an aggregate table (optionally filtered and with selected columns) to context/.
nets_stox_export <- function(file, survey_dir, name, ..., columns = NULL, object = NULL) {
  d <- nets_stox_read(file, object)
  det <- nets_stox_detail_cols(names(d))
  if (length(det)) {
    stop("This is a detail table (", paste(det, collapse = ", "),
         "). Use nets_stox_summarise() to aggregate it instead.", call. = FALSE)
  }
  filters <- rlang::enquos(...)
  out <- d |> filter(!!!filters)
  if (!is.null(columns)) out <- select(out, all_of(columns))
  note <- paste0("export",
                 if (length(filters)) paste0("; filter: ", paste(map_chr(filters, rlang::as_label), collapse = " & ")),
                 if (!is.null(columns)) paste0("; columns: ", paste(columns, collapse = ", ")))
  .nets_stox_write(out, survey_dir, name, file, note)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2 || args[1] != "inventory") {
    cat("Usage: Rscript nets_stox.R inventory <survey_dir> [<stox_path> ...]\n")
    quit(status = 1)
  }
  nets_stox_inventory(args[2], if (length(args) > 2) args[-(1:2)] else NULL)
}
