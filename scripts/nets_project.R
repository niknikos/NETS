# nets_project.R — syntheses of one survey or of several surveys together.
#
# Usage:
#   Rscript nets_project.R new <name> <BODY> <survey_id> [<survey_id> ...]
#
# A synthesis usually draws on one survey (which may have several reports). A synthesis of
# several surveys — a time series, or neighbouring surveys combined for one meeting — lives
# in a *synthesis project*:
#
#   <workspace>/_syntheses/<name>/
#     synthesis.yaml            body, meeting, member surveys, agreed wording
#     evidence/derived-log.csv  values calculated across surveys (ids D001, D002, ...)
#     outputs/<BODY>/           drafts and release checks
#
# Each member survey keeps its own survey.yaml (clearance) and evidence log (verification):
# nothing is copied or merged on disk, so a person's verification is never overwritten. In
# the project, entries are cited by qualified ids, "<survey_id>/E012"; cross-survey values
# are D ids whose derivation names the qualified ids they come from. A derived value is
# cleared only if every entry it is calculated from is cleared.
#
# nets_synthesis_context() gives templates and the release check one view of either case.

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

nets_is_project <- function(dir) file.exists(file.path(dir, "synthesis.yaml"))

nets_new_project <- function(name, body, surveys, workspace = NULL, title = "", meeting = "",
                             language = "en") {
  body <- str_to_upper(body)
  workspace <- workspace %||% nets_read_config()$workspace_path
  if (is.null(workspace)) stop("No workspace given and no workspace_path in ", nets_config_path(), call. = FALSE)
  workspace <- path.expand(workspace)
  nets_assert_safe_workspace(workspace)
  if (length(surveys) < 2) stop("A synthesis project combines two or more surveys; for one survey ",
                                "use nets_new_synthesis.R on the survey folder.", call. = FALSE)
  for (s in surveys) {
    m <- nets_read_manifest(file.path(workspace, s))
    if (is.null(m$reporting[[body]])) {
      stop("Survey ", s, " has no reporting entry for ", body, " in its survey.yaml. ",
           "Record clearance per area for ", body, " there first.", call. = FALSE)
    }
  }
  dir <- file.path(workspace, "_syntheses", nets_slug(name))
  if (file.exists(file.path(dir, "synthesis.yaml"))) stop("Synthesis project already exists: ", dir, call. = FALSE)
  dir.create(file.path(dir, "evidence"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(dir, "outputs"), showWarnings = FALSE)
  q <- function(x) paste0('"', str_replace_all(x, '"', "'"), '"')
  tmpl <- readLines(file.path(nets_root(), "templates", "synthesis.yaml"), warn = FALSE)
  set <- function(lines, key, value) str_replace(lines, paste0("^", key, ":\\s*\\S*(\\s+#.*)?$"),
                                                 paste0(key, ": ", value, "\\1"))
  tmpl <- tmpl |>
    set("name", q(name)) |> set("body", body) |> set("title", q(title)) |>
    set("meeting", q(meeting)) |> set("language", language) |>
    set("surveys", paste0("[", paste(map_chr(surveys, q), collapse = ", "), "]"))
  writeLines(tmpl, file.path(dir, "synthesis.yaml"))
  nets_ev_template(file.path(dir, "evidence", "derived-log.csv"))
  writeLines(c(
    "# Synthesis project", "",
    "Combines the surveys listed in synthesis.yaml. Clearance and verification stay in each",
    "survey's own folder. `evidence/derived-log.csv` holds values calculated across surveys",
    "(ids D001, ...); each derivation names the qualified ids it uses, e.g.",
    "`2022402/E030 - 2012401/E018`. AI agents follow each member survey's AGENT-READ-POLICY.md."
  ), file.path(dir, "README.md"))
  message("Created synthesis project ", dir)
  invisible(dir)
}

nets_read_project <- function(dir) {
  nets_assert_local_session()
  p <- yaml::read_yaml(file.path(dir, "synthesis.yaml"))
  p$body <- str_to_upper(p$body %||% "")
  if (!nzchar(p$body)) stop("synthesis.yaml needs a body.", call. = FALSE)
  p$surveys <- unlist(p$surveys)
  if (length(p$surveys) < 2) stop("synthesis.yaml should list two or more surveys.", call. = FALSE)
  # Surveys are folder names in the workspace (the parent of _syntheses/), or full paths.
  ws <- dirname(dirname(normalizePath(dir, mustWork = FALSE)))
  p$survey_dirs <- map_chr(p$surveys, ~ if (dir.exists(.x)) .x else file.path(ws, .x))
  p
}

# Ids referred to in a derivation: qualified survey ids and D ids.
nets_derivation_refs <- function(x) {
  unique(c(unlist(str_extract_all(x, "[A-Za-z0-9._-]+/E\\d{3,}")),
           unlist(str_extract_all(x, "(?<![\\w/])D\\d{3,}\\b"))))
}

# One view of the material behind a synthesis. `dir` is a survey folder or a project folder.
nets_synthesis_context <- function(dir, body = NULL) {
  project <- nets_is_project(dir)
  if (project) {
    p <- nets_read_project(dir)
    if (!is.null(body) && nzchar(body) && str_to_upper(body) != p$body) {
      stop("This synthesis project is for ", p$body, ", not ", str_to_upper(body), ".", call. = FALSE)
    }
    body <- p$body
    survey_dirs <- p$survey_dirs
  } else {
    if (is.null(body) || !nzchar(body)) stop("Name the body (e.g. CECAF).", call. = FALSE)
    body <- str_to_upper(body)
    survey_dirs <- dir
  }

  manifests <- map(survey_dirs, nets_read_manifest)
  ids <- map_chr(manifests, ~ as.character(.x$survey_id))
  names(manifests) <- ids
  missing_body <- ids[map_lgl(manifests, ~ is.null(.x$reporting[[body]]))]
  if (length(missing_body)) {
    stop("survey.yaml has no reporting entry for ", body, " (", paste(missing_body, collapse = ", "),
         "). Add one, with clearance per area, first.", call. = FALSE)
  }

  clearance <- map2_dfr(manifests, ids, ~ nets_clearance(.x) |> filter(body == !!body) |> mutate(survey_id = .y)) |>
    mutate(is_cleared = status %in% c("cleared", "not_required"))

  # Evidence: each survey's own log; in a project, ids are qualified with the survey id.
  ev <- map2_dfr(seq_along(survey_dirs), ids, function(i, sid) {
    f <- file.path(survey_dirs[i], "evidence", "evidence-log.csv")
    if (!file.exists(f)) return(tibble())
    e <- nets_ev_load(f, manifests[[i]])
    if (!nrow(e)) return(tibble())
    mutate(e, local_id = id, survey_id = sid, id = if (project) paste0(sid, "/", id) else id)
  })
  if (project) {
    f <- file.path(dir, "evidence", "derived-log.csv")
    if (file.exists(f)) {
      d <- nets_ev_load(f, NULL, id_prefix = "D")
      if (nrow(d)) {
        bad <- d$id[d$evidence_class != "derived"]
        if (length(bad)) stop("derived-log.csv holds derived values only: ", paste(bad, collapse = ", "), call. = FALSE)
        ev <- bind_rows(ev, mutate(d, local_id = id, survey_id = ""))
      }
    }
  }
  if (!nrow(ev)) {
    ev <- as_tibble(setNames(rep(list(character()), length(nets_ev_columns)), nets_ev_columns)) |>
      mutate(source_label = character(), local_id = character(), survey_id = character())
  }
  ev$multi <- project

  # Clearance of each entry. A survey's whole-survey value (ALL) is cleared for use but
  # flagged when the survey has uncleared areas; a derived project value is cleared only if
  # every entry it is calculated from is cleared, and is sensitive if any of them is.
  cl_state <- function(sid, area) {
    rows <- clearance[clearance$survey_id == sid, ]
    if (area == "ALL") return(TRUE)
    isTRUE(rows$is_cleared[rows$area_id == area][1])
  }
  ev$cleared <- map2_lgl(ev$survey_id, ev$area_id, ~ if (nzchar(.x)) cl_state(.x, .y) else NA)
  ev$partial <- map2_lgl(ev$survey_id, ev$area_id, function(sid, area) {
    nzchar(sid) && area == "ALL" && !all(clearance$is_cleared[clearance$survey_id == sid])
  })
  ev$sensitive_src <- ev$sensitivity == "sensitive"
  problems <- character()
  d_idx <- which(!nzchar(ev$survey_id))
  if (length(d_idx)) {
    refs <- map(ev$derivation[d_idx], nets_derivation_refs)
    unknown <- setdiff(unlist(refs), ev$id)
    if (length(unknown)) problems <- c(problems, paste("derived-log.csv refers to unknown ids:", paste(unknown, collapse = ", ")))
    empty <- ev$id[d_idx][lengths(refs) == 0]
    if (length(empty)) problems <- c(problems, paste("derivation names no source ids (use <survey_id>/E###):", paste(empty, collapse = ", ")))
    for (pass in seq_len(length(d_idx) + 1)) {
      for (k in seq_along(d_idx)) {
        src <- ev[ev$id %in% refs[[k]], ]
        ev$cleared[d_idx[k]] <- length(refs[[k]]) > 0 && !length(setdiff(refs[[k]], ev$id)) && all(src$cleared %in% TRUE)
        ev$partial[d_idx[k]] <- any(src$partial %in% TRUE)
        ev$sensitive_src[d_idx[k]] <- ev$sensitivity[d_idx[k]] == "sensitive" || any(src$sensitive_src %in% TRUE)
      }
    }
  }

  meta <- if (project) {
    list(title = p$title %||% "", meeting = p$meeting %||% "", language = p$language %||% "en",
         due = p$due %||% "")
  } else {
    m <- manifests[[1]]; r <- m$reporting[[body]]
    list(title = m$title %||% "", meeting = r$meeting %||% "", language = r$language %||% "en",
         due = r$due %||% "")
  }

  list(project = project, dir = dir, body = body,
       label = if (project) p$name else ids[1],
       survey_ids = ids, manifests = manifests, clearance = clearance, ev = ev, meta = meta,
       problems = problems, out_dir = file.path(dir, "outputs", body))
}

# The data-ownership paragraph for a synthesis, from survey.yaml clearance.
nets_clearance_statement <- function(ctx) {
  cl <- ctx$clearance
  # In a project, an area cleared in some surveys but not others is named with its surveys.
  by_area <- cl |>
    mutate(area_name = factor(area_name, levels = unique(area_name))) |>   # keep survey.yaml order
    group_by(area_name) |>
    summarise(all_ok = all(is_cleared), any_ok = any(is_cleared),
              ok_in = paste(survey_id[is_cleared], collapse = ", "), .groups = "drop") |>
    mutate(area_name = as.character(area_name))
  cleared <- c(by_area$area_name[by_area$all_ok],
               with(filter(by_area, !all_ok, any_ok), paste0(area_name, " (survey ", ok_in, ")")))
  pending <- cl[!cl$is_cleared, ]
  txt <- paste0("The results presented here were collected under the EAF-Nansen Programme. Results for ",
                if (length(cleared)) nets_and(cleared) else "no area",
                " are presented with the agreement of the respective data owners.")
  if (nrow(pending)) {
    what <- if (ctx$project) paste0(pending$area_name, " (survey ", pending$survey_id, ")") else pending$area_name
    txt <- paste0(txt, " Results for ", nets_and(unique(what)), " are not included in this synthesis.")
  }
  paste(txt, "Requests for the underlying data should be addressed to the data owners.")
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) < 5 || args[1] != "new") {
    cat("Usage: Rscript nets_project.R new <name> <BODY> <survey_id> <survey_id> [...]\n")
    quit(status = 1)
  }
  nets_new_project(args[2], args[3], args[-(1:3)])
}
