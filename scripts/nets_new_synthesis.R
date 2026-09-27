# nets_new_synthesis.R — start a synthesis draft for one reporting body.
#
# Usage:
#   Rscript nets_new_synthesis.R <survey_dir> <BODY> ["<author>"]
#
# Copies templates/synthesis.qmd to outputs/<BODY>/<survey_id>_<BODY>_synthesis.qmd with the
# title, meeting and language taken from survey.yaml. Refuses to overwrite a draft, and
# refuses outright when the survey's context policy is local-only.

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

nets_new_synthesis <- function(survey_dir, body, author = "") {
  body <- str_to_upper(body)
  m <- nets_read_manifest(survey_dir)
  rep <- m$reporting[[body]]
  if (is.null(rep)) {
    stop("survey.yaml has no reporting entry for ", body,
         ". Add it, with clearance per area, before drafting.", call. = FALSE)
  }
  if (identical(m$context_policy, "local-only")) {
    stop("context_policy is local-only for this survey: the synthesis must not be drafted ",
         "with a cloud model. Draft it yourself or with a local model.", call. = FALSE)
  }
  out_dir <- file.path(survey_dir, "outputs", body)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(out_dir, paste0(nets_slug(m$survey_id), "_", body, "_synthesis.qmd"))
  if (file.exists(out)) stop("Draft already exists: ", out, call. = FALSE)

  title <- if (nzchar(m$title %||% "")) m$title else paste("Survey", m$survey_id)
  meeting <- if (nzchar(rep$meeting %||% "")) rep$meeting else body
  tmpl <- readLines(file.path(nets_root(), "templates", "synthesis.qmd"), warn = FALSE)
  filled <- tmpl |>
    str_replace_all(fixed("{{title}}"), str_replace_all(title, '"', "'")) |>
    str_replace_all(fixed("{{meeting}}"), str_replace_all(meeting, '"', "'")) |>
    str_replace_all(fixed("{{author}}"), author) |>
    str_replace_all(fixed("{{language}}"), rep$language %||% "en") |>
    str_replace_all(fixed("{{body}}"), body)
  writeLines(filled, out)
  message("Draft created: ", out)
  invisible(out)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    cat("Usage: Rscript nets_new_synthesis.R <survey_dir> <BODY> [\"<author>\"]\n")
    quit(status = 1)
  }
  nets_new_synthesis(args[1], args[2], if (length(args) > 2) args[3] else "")
}
