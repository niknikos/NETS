# nets_release_check.R — check a synthesis before it leaves your hands.
#
# Usage:
#   Rscript nets_release_check.R <survey_dir> <BODY> <file> [<file> ...]
#
# <file> may be the .qmd/.md source and/or rendered .html, .docx or .pdf output; check the
# source (for evidence tracing) AND the rendered file (for what the body will receive).
# Writes outputs/<BODY>/release-check.md and exits with status 1 if anything FAILs.
#
# FAIL  position with sub-degree precision; evidence id not in the log; evidence from an
#       area not cleared for this body; evidence marked sensitive; local-only survey.
# WARN  unverified evidence; uncleared area named in text; hard-coded numbers in the
#       source; draft/restricted markings; report not yet cleared.
# The check is a safety net, not an approval. The decision to send stays with you.

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
if (!exists("nets_ev_load", mode = "function")) source(file.path(.nets_scripts_dir, "nets_evidence.R"))

# Plain text of a draft in any of the supported formats, one element per line.
nets_read_output_text <- function(file) {
  ext <- str_to_lower(tools::file_ext(file))
  if (ext %in% c("qmd", "md", "rmd", "txt", "tex")) return(readLines(file, warn = FALSE, encoding = "UTF-8"))
  if (ext %in% c("html", "htm")) {
    x <- paste(readLines(file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    x <- str_remove_all(x, regex("<(script|style)[^>]*>.*?</\\1>", dotall = TRUE, ignore_case = TRUE))
    x <- str_replace_all(x, regex("<br\\s*/?>|</(p|div|li|tr|h[1-6])>", ignore_case = TRUE), "\n")
    x <- str_remove_all(x, "<[^>]+>")
    x <- str_replace_all(x, c("&deg;" = "\u00B0", "&#176;" = "\u00B0", "&amp;" = "&", "&nbsp;" = " ",
                              "&prime;" = "\u2032", "&#39;" = "'", "&quot;" = "\""))
    return(str_split(x, "\n")[[1]])
  }
  if (ext == "docx") {
    tmp <- tempfile()
    on.exit(unlink(tmp, recursive = TRUE))
    utils::unzip(file, files = "word/document.xml", exdir = tmp)
    x <- paste(readLines(file.path(tmp, "word", "document.xml"), warn = FALSE, encoding = "UTF-8"), collapse = "")
    x <- str_replace_all(x, "</w:p>", "\n")
    x <- str_remove_all(x, "<[^>]+>")
    return(str_split(x, "\n")[[1]])
  }
  if (ext == "pdf") return(unlist(str_split(pdftools::pdf_text(file), "\n")))
  stop("Unsupported file type: ", file, call. = FALSE)
}

# Prose lines of a .qmd/.Rmd: drop YAML header and code chunks, strip inline code.
nets_prose_lines <- function(lines) {
  keep <- rep(TRUE, length(lines))
  if (length(lines) && str_detect(lines[1], "^---\\s*$")) {
    end <- which(str_detect(lines[-1], "^---\\s*$"))[1] + 1
    if (!is.na(end)) keep[seq_len(end)] <- FALSE
  }
  in_chunk <- FALSE
  for (i in seq_along(lines)) {
    if (str_detect(lines[i], "^\\s*```")) { keep[i] <- FALSE; in_chunk <- !in_chunk; next }
    if (in_chunk) keep[i] <- FALSE
  }
  out <- lines
  out[!keep] <- ""
  str_remove_all(out, "`r [^`]*`")
}

nets_release_check <- function(survey_dir, body, files, write = TRUE) {
  body <- str_to_upper(body)
  m <- nets_read_manifest(survey_dir)
  cl <- nets_clearance(m)
  if (!body %in% cl$body) {
    stop("survey.yaml has no reporting entry for ", body, ". Add one (with clearance per area) first.",
         call. = FALSE)
  }
  cl_body <- filter(cl, body == !!body)
  cleared_areas <- cl_body$area_id[cl_body$status %in% c("cleared", "not_required")]

  ev_path <- file.path(survey_dir, "evidence", "evidence-log.csv")
  ev <- if (file.exists(ev_path)) nets_ev_load(ev_path, m) else NULL

  findings <- list()
  add <- function(level, check, detail, where = "") {
    findings[[length(findings) + 1]] <<- tibble(level = level, check = check, detail = detail, where = where)
  }

  if (identical(m$context_policy, "local-only")) {
    add("FAIL", "context policy", "survey.yaml says local-only: content must not have been drafted with a cloud model.")
  }
  if (!m$report_status %in% c("cleared", "published")) {
    add("WARN", "report status", paste0("report_status is '", m$report_status,
                                        "'. Confirm the data owners agree to this use before sending."))
  }
  if (!is.null(m$reporting[[body]]$due) && nzchar(m$reporting[[body]]$due %||% "")) {
    due <- suppressWarnings(as.Date(m$reporting[[body]]$due))
    if (!is.na(due) && due < Sys.Date()) add("WARN", "deadline", paste("Recorded deadline", due, "has passed."))
  }

  used_ids <- character()
  for (f in files) {
    lines <- nets_read_output_text(f)
    is_source <- str_to_lower(tools::file_ext(f)) %in% c("qmd", "rmd", "md")
    fname <- basename(f)

    # Positions with sub-degree precision.
    n_coord <- nets_count_coords(lines, keep_whole_degree = TRUE)
    for (i in which(n_coord > 0)) {
      add("FAIL", "coordinates", paste(n_coord[i], "position(s) with sub-degree precision"), paste0(fname, ":", i))
    }

    # Evidence ids referenced in the text or code.
    ids <- unique(unlist(str_extract_all(lines, "\\bE\\d{3,}\\b")))
    used_ids <- union(used_ids, ids)

    # Uncleared areas named in the text.
    for (j in seq_len(nrow(cl_body))) {
      if (cl_body$area_id[j] %in% cleared_areas) next
      names_j <- unique(c(cl_body$area_name[j], cl_body$aliases[[j]]))
      names_j <- names_j[nzchar(names_j)]
      if (!length(names_j)) next
      pat <- regex(paste0("\\b(", paste(str_replace_all(names_j, "([.()\\[\\]])", "\\\\\\1"), collapse = "|"), ")\\b"),
                   ignore_case = TRUE)
      hit <- which(str_detect(lines, pat))
      if (length(hit)) {
        add("WARN", "uncleared area named",
            paste0(cl_body$area_name[j], " (clearance for ", body, ": ", cl_body$status[j],
                   "). Make sure no results for it are given."),
            paste0(fname, ":", paste(head(hit, 5), collapse = ",")))
      }
    }

    # Markings that should not travel.
    mark <- which(str_detect(lines, regex("\\b(draft|restricted|confidential|not for citation|do not cite|internal use)\\b",
                                          ignore_case = TRUE)))
    if (length(mark)) add("WARN", "markings", "Draft/restricted wording present; confirm it is intended.",
                          paste0(fname, ":", paste(head(mark, 5), collapse = ",")))

    # Numbers typed into prose instead of drawn from the evidence log.
    if (is_source) {
      prose <- nets_prose_lines(lines)
      num_pat <- "(?<![\\w.])\\d{1,3}(?:[ ,]\\d{3})+(?:\\.\\d+)?(?![\\w])|(?<![\\w.])\\d+\\.\\d+(?![\\w.])|(?<![\\w.])\\d{3,}(?![\\w.])"
      ctx_pat <- "(?i)(table|figure|fig\\.|section|annex|p\\.|page|pp\\.)\\s*$"
      hard <- map(seq_along(prose), function(i) {
        locs <- str_locate_all(prose[i], num_pat)[[1]]
        if (!nrow(locs)) return(character())
        vals <- str_sub(prose[i], locs[, 1], locs[, 2])
        before <- str_sub(prose[i], pmax(1, locs[, 1] - 12), locs[, 1] - 1)
        is_year <- str_detect(vals, "^(19|20)\\d{2}$")
        vals[!is_year & !str_detect(before, ctx_pat)]
      })
      hit <- which(lengths(hard) > 0)
      if (length(hit)) {
        add("WARN", "hard-coded numbers",
            paste0(sum(lengths(hard)), " number(s) typed in prose. Pull values from the evidence log or confirm each is correct."),
            paste0(fname, ":", paste(head(hit, 10), collapse = ",")))
      }
    }
  }

  # Evidence behind the text.
  if (length(used_ids)) {
    if (is.null(ev)) {
      add("FAIL", "evidence", "Text refers to evidence ids but evidence/evidence-log.csv is missing.")
    } else {
      unknown <- setdiff(used_ids, ev$id)
      if (length(unknown)) add("FAIL", "evidence", paste("Ids not in the log:", paste(unknown, collapse = ", ")))
      used <- filter(ev, id %in% used_ids)
      unc <- used |> filter(area_id != "ALL", !area_id %in% cleared_areas)
      if (nrow(unc)) {
        add("FAIL", "clearance", paste0("Evidence from areas not cleared for ", body, ": ",
                                        paste0(unc$id, " (", unc$area_id, ")", collapse = ", ")))
      }
      all_area <- used |> filter(area_id == "ALL")
      if (nrow(all_area) && length(setdiff(cl_body$area_id, cleared_areas))) {
        add("WARN", "clearance", paste0("Whole-survey values (", paste(all_area$id, collapse = ", "),
                                        ") include areas not yet cleared for ", body, "."))
      }
      sens <- used |> filter(sensitivity == "sensitive")
      if (nrow(sens)) add("FAIL", "sensitivity", paste("Sensitive evidence used:", paste(sens$id, collapse = ", "),
                                                       "\u2014 remove, or aggregate and re-classify with the data owner."))
      unver <- used |> filter(!nzchar(str_trim(verified_by)))
      if (nrow(unver)) add("WARN", "verification", paste("Not yet checked against the original by a person:",
                                                         paste(unver$id, collapse = ", ")))
    }
  }

  res <- bind_rows(findings)
  if (!nrow(res)) res <- tibble(level = character(), check = character(), detail = character(), where = character())
  res <- arrange(res, factor(level, c("FAIL", "WARN")))
  verdict <- if (any(res$level == "FAIL")) "FAIL" else if (any(res$level == "WARN")) "PASS WITH WARNINGS" else "PASS"

  if (write) {
    out_dir <- file.path(survey_dir, "outputs", body)
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    report <- c(
      paste0("# Release check \u2014 ", m$survey_id, " for ", body), "",
      paste0("**Result: ", verdict, "** \u00B7 ", format(Sys.time(), "%Y-%m-%d %H:%M"), " \u00B7 NETS ", nets_version()), "",
      paste0("Files checked: ", paste(basename(files), collapse = ", ")), "",
      "## Clearance recorded for this body", "",
      "| Area | Status | By | Date | Scope |", "|---|---|---|---|---|",
      pmap_chr(cl_body, function(area_name, status, cleared_by, cleared_on, scope, ...) {
        paste0("| ", area_name, " | ", status, " | ", cleared_by, " | ", cleared_on, " | ", scope, " |")
      }),
      "", "## Findings", "",
      if (nrow(res)) c("| Level | Check | Detail | Where |", "|---|---|---|---|",
                       pmap_chr(res, function(level, check, detail, where) {
                         paste0("| ", level, " | ", check, " | ", str_replace_all(detail, "\\|", "/"), " | ", where, " |")
                       }))
      else "No findings.",
      "", "This check is a safety net. It cannot confirm that interpretations are sound or that",
      "every sensitive detail was caught; the decision to send remains with the responsible scientist."
    )
    writeLines(report, file.path(out_dir, "release-check.md"))
    message("Release check: ", verdict, " \u2014 see ", file.path(out_dir, "release-check.md"))
  }
  invisible(list(verdict = verdict, findings = res))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 3) {
    cat("Usage: Rscript nets_release_check.R <survey_dir> <BODY> <file> [<file> ...]\n")
    quit(status = 1)
  }
  r <- nets_release_check(args[1], args[2], args[-(1:2)])
  quit(status = if (r$verdict == "FAIL") 1 else 0)
}
