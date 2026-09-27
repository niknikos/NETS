# nets_new_synthesis.R — start a synthesis draft for one reporting body.
#
# Usage:
#   Rscript nets_new_synthesis.R <survey_dir | project_dir> <BODY> ["<author>"]
#
# <survey_dir> is one survey's folder; <project_dir> is a synthesis project combining several
# surveys (see nets_project.R). Copies templates/synthesis.qmd to
# outputs/<BODY>/<id>_<BODY>_synthesis.qmd, with title, meeting and language from
# survey.yaml or synthesis.yaml. Refuses to overwrite a draft, and refuses outright when any
# survey's context policy is local-only.

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
if (!exists("nets_synthesis_context", mode = "function")) source(file.path(.nets_scripts_dir, "nets_project.R"))

nets_new_synthesis <- function(dir, body = NULL, author = "") {
  if (!nets_is_project(dir)) {
    m <- nets_read_manifest(dir)
    if (is.null(body) || is.null(m$reporting[[str_to_upper(body)]])) {
      stop("survey.yaml has no reporting entry for ", body,
           ". Add it, with clearance per area, before drafting.", call. = FALSE)
    }
  }
  ctx <- nets_synthesis_context(dir, body)
  local_only <- names(ctx$manifests)[map_lgl(ctx$manifests, ~ identical(.x$context_policy, "local-only"))]
  if (length(local_only)) {
    stop("context_policy is local-only for ", paste(local_only, collapse = ", "), ": the synthesis ",
         "must not be drafted with a cloud model. Draft it yourself or with a local model.", call. = FALSE)
  }
  body <- ctx$body
  out_dir <- ctx$out_dir
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out <- file.path(out_dir, paste0(nets_slug(ctx$label), "_", body, "_synthesis.qmd"))
  if (file.exists(out)) stop("Draft already exists: ", out, call. = FALSE)

  title <- if (nzchar(ctx$meta$title)) ctx$meta$title else if (ctx$project) ctx$label else paste("Survey", ctx$label)
  meeting <- if (nzchar(ctx$meta$meeting)) ctx$meta$meeting else body
  tmpl <- readLines(file.path(nets_root(), "templates", "synthesis.qmd"), warn = FALSE)
  filled <- tmpl |>
    str_replace_all(fixed("{{title}}"), str_replace_all(title, '"', "'")) |>
    str_replace_all(fixed("{{meeting}}"), str_replace_all(meeting, '"', "'")) |>
    str_replace_all(fixed("{{author}}"), author) |>
    str_replace_all(fixed("{{language}}"), ctx$meta$language %||% "en") |>
    str_replace_all(fixed("{{body}}"), body)
  writeLines(filled, out)
  message("Draft created: ", out)
  invisible(out)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 2) {
    cat("Usage: Rscript nets_new_synthesis.R <survey_dir | project_dir> <BODY> [\"<author>\"]\n")
    quit(status = 1)
  }
  nets_new_synthesis(args[1], args[2], if (length(args) > 2) args[3] else "")
}
