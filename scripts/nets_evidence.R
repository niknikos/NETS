# nets_evidence.R — the evidence log behind every number in a NETS synthesis.
#
# Each quantitative statement in a synthesis resolves to one row of
# evidence/evidence-log.csv, which records the value, its uncertainty, exactly where it
# came from (document, PDF page, table/figure), whether it was reported, derived from other
# entries, or computed locally from haul data or StoX outputs, how sensitive it is, and who
# checked it. Synthesis documents pull values with nets_ev_value() instead of typing them,
# so text and evidence cannot drift.
#
# Typical use inside a .qmd:
#   source(file.path(nets_path, "scripts", "nets_evidence.R"))
#   ev <- nets_ev_load("../../evidence/evidence-log.csv")
#   v  <- function(id, ...) nets_ev_value(ev, id, ...)
#   ...  the acoustic biomass was `r v("E004")` `r nets_ev_cite(ev, "E004")`

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

nets_ev_columns <- c(
  "id",               # E001, E002, ...
  "claim",            # what the value is, in words ("Acoustic biomass of Sardinella aurita, total survey area")
  "value",            # the number as reported (no thousands separators)
  "unit",             # e.g. "tonnes", "million individuals", "kg/nm2", "cm"
  "uncertainty",      # e.g. CV or interval as reported; empty if none reported
  "uncertainty_type", # e.g. "CV", "95% CI", "SD", "none reported"
  "species_or_group", # scientific name or group
  "area_id",          # an area id from survey.yaml, or "ALL" for the whole survey
  "period",           # survey period or year
  "source_doc",       # file name in sources/ (report PDF or StoX output), or the aggregate file a computation wrote
  "page",             # PDF page index (for reports)
  "locator",          # "Table 5", "Figure 3", "Section 3.2", the StoX table/process name, or the row of an aggregate file
  "source_type",      # report | stox | haul_data | manifest | other
  "evidence_class",   # reported | derived | computed
  "derivation",       # derived: how it was calculated, from which ids; computed: the method and the script that produced it
  "sensitivity",      # public | restricted | sensitive
  "entered_by",       # "agent" or a person's initials
  "verified_by",      # initials of the person who checked it against the original; empty = unverified
  "notes"
)

nets_ev_template <- function(path) {
  if (file.exists(path)) stop("Refusing to overwrite existing evidence log: ", path, call. = FALSE)
  write_csv(as_tibble(setNames(rep(list(character()), length(nets_ev_columns)), nets_ev_columns)), path)
  invisible(path)
}

nets_ev_load <- function(path, manifest = NULL, id_prefix = "E") {
  ev <- read_csv(path, col_types = cols(.default = col_character()), show_col_types = FALSE,
                 na = character())
  problems <- nets_ev_validate(ev, manifest, id_prefix)
  if (length(problems)) {
    stop("Evidence log problems in ", path, ":\n- ", paste(problems, collapse = "\n- "), call. = FALSE)
  }
  # Citations name each document by the label given under `documents` in survey.yaml (useful
  # when a survey has several reports), or by its file name.
  labels <- nets_document_labels(manifest)
  if (!"source_label" %in% names(ev)) ev$source_label <- character(nrow(ev))
  ev$source_label <- if_else(nzchar(ev$source_label), ev$source_label,
                             unname(coalesce(labels[ev$source_doc], ev$source_doc)))
  ev
}

# Named vector file -> label from survey.yaml:
#   documents:
#     - { file: "cruise-report.pdf", label: "EAF-Nansen/CR/2022/02" }
nets_document_labels <- function(manifest) {
  docs <- manifest$documents %||% list()
  if (!length(docs)) return(c(x = NA_character_)[0])
  setNames(map_chr(docs, ~ as.character(.x$label %||% .x$file)), map_chr(docs, ~ as.character(.x$file)))
}

nets_ev_validate <- function(ev, manifest = NULL, id_prefix = "E") {
  p <- character()
  missing_cols <- setdiff(nets_ev_columns, names(ev))
  if (length(missing_cols)) return(paste("missing columns:", paste(missing_cols, collapse = ", ")))
  if (!nrow(ev)) return(p)
  bad_id <- ev$id[!str_detect(ev$id, paste0("^", id_prefix, "\\d{3,}$"))]
  if (length(bad_id)) p <- c(p, paste0("ids must look like ", id_prefix, "001: ", paste(bad_id, collapse = ", ")))
  dup <- unique(ev$id[duplicated(ev$id)])
  if (length(dup)) p <- c(p, paste("duplicated ids:", paste(dup, collapse = ", ")))
  chk <- function(col, allowed) {
    bad <- ev$id[!ev[[col]] %in% allowed]
    if (length(bad)) paste0(col, " must be one of ", paste(allowed, collapse = "/"), ": ", paste(bad, collapse = ", "))
  }
  p <- c(p,
         chk("evidence_class", c("reported", "derived", "computed")),
         chk("sensitivity", c("public", "restricted", "sensitive")),
         chk("source_type", c("report", "stox", "haul_data", "manifest", "other")))
  no_deriv <- ev$id[ev$evidence_class == "derived" & !nzchar(str_trim(ev$derivation))]
  if (length(no_deriv)) p <- c(p, paste("derived values need a derivation:", paste(no_deriv, collapse = ", ")))
  # Computed: calculated locally from haul data or StoX outputs; the method and the script
  # must be named, so a person can check the computation (there is no page to check).
  no_method <- ev$id[ev$evidence_class == "computed" & !nzchar(str_trim(ev$derivation))]
  if (length(no_method)) p <- c(p, paste("computed values need their method and script in derivation:", paste(no_method, collapse = ", ")))
  no_src <- ev$id[!nzchar(str_trim(ev$source_doc))]
  if (length(no_src)) p <- c(p, paste("source_doc is empty:", paste(no_src, collapse = ", ")))
  no_page <- ev$id[ev$source_type == "report" & ev$evidence_class == "reported" & !nzchar(str_trim(ev$page))]
  if (length(no_page)) p <- c(p, paste("report values need a page:", paste(no_page, collapse = ", ")))
  if (!is.null(manifest)) {
    ok_areas <- c("ALL", map_chr(manifest$areas, "id"))
    bad_area <- ev$id[!ev$area_id %in% ok_areas]
    if (length(bad_area)) p <- c(p, paste("area_id not in survey.yaml:", paste(bad_area, collapse = ", ")))
  }
  p
}

nets_ev_row <- function(ev, id) {
  r <- ev[ev$id == id, ]
  if (nrow(r) != 1) stop("Evidence id not found (or duplicated): ", id, call. = FALSE)
  r
}

# Formatted value with unit, e.g. "412,000 tonnes (CV 0.21)".
nets_ev_value <- function(ev, id, digits = NULL, big_mark = ",", unit = TRUE, uncertainty = FALSE) {
  r <- nets_ev_row(ev, id)
  num <- suppressWarnings(as.numeric(r$value))
  txt <- if (is.na(num)) {
    r$value
  } else {
    if (!is.null(digits)) num <- round(num, digits)
    format(num, big.mark = big_mark, scientific = FALSE, trim = TRUE)
  }
  if (unit && nzchar(r$unit)) txt <- paste(txt, r$unit)
  if (uncertainty && nzchar(r$uncertainty)) txt <- paste0(txt, " (", r$uncertainty_type, " ", r$uncertainty, ")")
  txt
}

# Human-readable source, e.g. "(report.pdf, p. 23, Table 5)". style = "id" adds the id,
# which is useful in drafts and for the release check to trace statements.
nets_ev_cite <- function(ev, id, style = c("source", "id", "both")) {
  style <- match.arg(style)
  r <- nets_ev_row(ev, id)
  doc <- if ("source_label" %in% names(r) && nzchar(r$source_label)) r$source_label else r$source_doc
  where <- c(doc, if (nzchar(r$page)) paste0("p. ", r$page), if (nzchar(r$locator)) r$locator)
  src <- paste(where, collapse = ", ")
  # In a synthesis of several surveys, say which survey the entry comes from.
  if ("survey_id" %in% names(r) && isTRUE(r$multi) && nzchar(r$survey_id)) src <- paste0("survey ", r$survey_id, ": ", src)
  if (r$evidence_class == "derived") src <- paste0("derived from ", src)
  if (r$evidence_class == "computed") src <- paste0("computed from ", src)
  switch(style,
         source = paste0("(", src, ")"),
         id = paste0("[", id, "]"),
         both = paste0("(", src, "; ", id, ")"))
}

# Record the evidence ids a rendered document used, next to its source file
# (<file>.evidence-ids.txt), so the release check sees ids that code built (tables filled
# by helper functions, ids looked up by claim) and not only ids written in the text.
# Called from the evidence annex chunk of the NETS templates.
nets_record_used_ids <- function(ids, input = knitr::current_input(dir = TRUE)) {
  if (is.null(input) || !nzchar(input)) return(invisible(NULL))
  out <- paste0(tools::file_path_sans_ext(input), ".evidence-ids.txt")
  writeLines(sort(unique(ids[!is.na(ids) & nzchar(ids)])), out)
  invisible(out)
}

# The evidence entries a document relies on, for an annex table. Sensitive entries are
# excluded unless explicitly requested.
nets_ev_annex <- function(ev, ids, include_sensitive = FALSE) {
  ev |>
    filter(id %in% ids, include_sensitive | sensitivity != "sensitive") |>
    transmute(
      ID = id, Statement = claim,
      Value = map_chr(id, ~ nets_ev_value(ev, .x)),
      Uncertainty = if_else(nzchar(uncertainty), paste(uncertainty_type, uncertainty), "not reported"),
      Source = map_chr(id, ~ str_remove_all(nets_ev_cite(ev, .x), "^\\(|\\)$")),
      Type = evidence_class
    )
}
