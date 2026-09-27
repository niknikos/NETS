# nets_new_survey.R — create a survey folder in the NETS workspace.
#
# Usage:
#   Rscript nets_new_survey.R <survey_id> [<workspace_path>]
#
# The workspace defaults to `workspace_path` in ~/.nets/config.json. The script refuses a
# workspace inside a git repository or at a filesystem root, and never overwrites an
# existing survey.yaml.

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
if (!exists("nets_ev_template", mode = "function")) source(file.path(.nets_scripts_dir, "nets_evidence.R"))

nets_agent_read_policy <- c(
  "# What an AI agent may read in this survey folder",
  "",
  "This folder holds confidential survey material. NETS keeps it in separate subfolders so",
  "that it is always clear what may enter an agent's context (and so reach a model provider).",
  "",
  "| Folder | Contents | Agent may read? |",
  "|---|---|---|",
  "| `survey.yaml` | ownership, clearance, sensitivity | **yes, always first** |",
  "| `sources/` | original PDFs and StoX projects | **no** \u2014 only NETS scripts open these |",
  "| `local/` | full, unredacted extracted text | **no** |",
  "| `context/` | redacted report text, indexes, StoX inventory and summaries | yes, unless `context_policy` says otherwise |",
  "| `evidence/` | the evidence log | yes, unless `context_policy` is `local-only` |",
  "| `outputs/` | synthesis drafts and release checks | yes |",
  "",
  "`context_policy: aggregates-only` limits the agent to `context/*.index.md`, the StoX",
  "inventory and `context/stox-summaries/`. `context_policy: local-only` means no content from",
  "this survey may be sent to a cloud model: the agent may run scripts but must not read",
  "`context/` or `evidence/`."
)

nets_new_survey <- function(survey_id, workspace = NULL) {
  if (!nzchar(survey_id) || str_detect(survey_id, "[/\\\\]")) {
    stop("Give a plain survey id without path separators.", call. = FALSE)
  }
  workspace <- workspace %||% nets_read_config()$workspace_path
  if (is.null(workspace)) {
    stop("No workspace given and no workspace_path in ", nets_config_path(),
         ". Run the nets-install skill or pass a workspace path.", call. = FALSE)
  }
  workspace <- path.expand(workspace)
  nets_assert_safe_workspace(workspace)

  survey_dir <- file.path(workspace, survey_id)
  if (file.exists(file.path(survey_dir, "survey.yaml"))) {
    stop("Survey already exists: ", survey_dir, call. = FALSE)
  }
  for (d in c("sources/reports", "sources/stox", "local", "context/stox-summaries",
              "evidence", "outputs")) {
    dir.create(file.path(survey_dir, d), recursive = TRUE, showWarnings = FALSE)
  }
  # A conservative default chosen at install time (e.g. while data agreements are being
  # clarified) carries into every new survey.
  policy <- nets_read_config()$default_context_policy %||% "standard"
  if (!policy %in% nets_context_policies) policy <- "aggregates-only"
  tmpl <- readLines(file.path(nets_root(), "templates", "survey.yaml"), warn = FALSE) |>
    str_replace_all(fixed("{{survey_id}}"), survey_id) |>
    str_replace("^context_policy: standard$", paste0("context_policy: ", policy))
  writeLines(tmpl, file.path(survey_dir, "survey.yaml"))
  writeLines(nets_agent_read_policy, file.path(survey_dir, "AGENT-READ-POLICY.md"))
  writeLines(
    "LOCAL ONLY. Unredacted extracts. AI agents must not read files in this folder.",
    file.path(survey_dir, "local", "README-AGENTS-DO-NOT-READ.txt")
  )
  nets_ev_template(file.path(survey_dir, "evidence", "evidence-log.csv"))

  message("Created ", survey_dir)
  message("Next: fill in survey.yaml (areas, owners, clearance), then put the report PDFs in ",
          "sources/reports/ and any StoX projects in sources/stox/.")
  invisible(survey_dir)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args) || args[1] %in% c("-h", "--help")) {
    cat("Usage: Rscript nets_new_survey.R <survey_id> [<workspace_path>]\n")
    quit(status = if (length(args)) 0 else 1)
  }
  nets_new_survey(args[1], if (length(args) > 1) args[2] else NULL)
}
