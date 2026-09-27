# nets_common.R — shared helpers for the NETS scripts.
#
# The other NETS scripts source this file themselves. Nothing here reads report content:
# it resolves paths, reads and validates the survey manifest, and holds the coordinate
# patterns that redaction (nets_ingest_pdf.R) and the release check share.

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(purrr)
  library(readr)
  library(tibble)
})

# Coordinate patterns and extracted report text are Unicode. Under a non-UTF-8 locale (e.g.
# "C" on some servers) degree signs are mangled and positions can slip through, so switch
# the character locale to UTF-8 when possible.
if (!isTRUE(l10n_info()$`UTF-8`)) {
  ok <- FALSE
  for (loc in c("C.UTF-8", "en_US.UTF-8", "en_GB.UTF-8", "English_United Kingdom.utf8")) {
    if (nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) { ok <- TRUE; break }
  }
  if (!ok) warning("R is not running in a UTF-8 locale; coordinate detection may miss positions.",
                   call. = FALSE)
}

# ---- Paths and configuration ----------------------------------------------------------

# Home directory. On Windows R expands "~" to (often OneDrive-redirected) Documents,
# so use USERPROFILE there, as BAIT does.
nets_home <- function() {
  if (.Platform$OS.type == "windows") Sys.getenv("USERPROFILE") else path.expand("~")
}

# NETS_CONFIG can point to another config file (separate setups, tests).
nets_config_path <- function() {
  Sys.getenv("NETS_CONFIG", unset = file.path(nets_home(), ".nets", "config.json"))
}

nets_read_config <- function() {
  f <- nets_config_path()
  if (!file.exists(f)) return(list())
  jsonlite::read_json(f)
}

nets_root <- function() normalizePath(file.path(.nets_scripts_dir, ".."), mustWork = FALSE)

nets_version <- function() {
  f <- file.path(nets_root(), "VERSION")
  if (!file.exists(f)) return("unknown")
  v <- sub("^version:[[:space:]]*", "", grep("^version:", readLines(f, warn = FALSE), value = TRUE))
  if (length(v)) v[1] else "unknown"
}

# Returns the git work tree that contains `path`, or NULL.
nets_enclosing_repo <- function(path) {
  p <- normalizePath(path, mustWork = FALSE)
  repeat {
    if (dir.exists(file.path(p, ".git")) || file.exists(file.path(p, ".git"))) return(p)
    parent <- dirname(p)
    if (identical(parent, p)) return(NULL)
    p <- parent
  }
}

# The workspace holds confidential material. Refuse locations where it could be pushed or
# where it would sit at a filesystem root; warn about cloud-synced folders.
# Real survey material belongs on the user's own machine. A cloud agent session (Claude Code
# on the web sets CLAUDE_CODE_REMOTE) would hold it in a remote container, and cannot reach
# institute systems such as ResourceSpace anyway. Developing NETS itself in the cloud is
# fine: the test suite sets NETS_SYNTHETIC_ONLY=true because it uses invented material only.
nets_is_cloud_session <- function() {
  tolower(Sys.getenv("CLAUDE_CODE_REMOTE")) %in% c("true", "1", "yes")
}

nets_assert_local_session <- function() {
  if (nets_is_cloud_session() && !identical(Sys.getenv("NETS_SYNTHETIC_ONLY"), "true")) {
    stop("This looks like a cloud agent session (CLAUDE_CODE_REMOTE is set). NETS handles real ",
         "survey material only on your own computer: start Claude Code there (desktop app or ",
         "terminal) inside the institute's network. Cloud sessions are for developing NETS ",
         "with synthetic material.", call. = FALSE)
  }
  invisible(TRUE)
}

nets_assert_safe_workspace <- function(path) {
  nets_assert_local_session()
  p <- normalizePath(path, mustWork = FALSE)
  if (p %in% c("/", "/usr", "/opt", "/etc", "/var") || grepl("^[A-Za-z]:[\\\\/]?$", p) ||
      grepl("^[A-Za-z]:[\\\\/](Windows|Program Files)", p, ignore.case = TRUE)) {
    stop("Refusing to use a filesystem root or system directory as a NETS workspace: ", p,
         "\nChoose a folder under your home directory instead.", call. = FALSE)
  }
  repo <- nets_enclosing_repo(p)
  if (!is.null(repo)) {
    stop("The NETS workspace must not be inside a git repository (found one at ", repo, ").",
         "\nSurvey reports and extracts could be committed and pushed from there.",
         call. = FALSE)
  }
  if (grepl("dropbox|onedrive|owncloud|nextcloud|google ?drive|icloud", p, ignore.case = TRUE)) {
    warning("The workspace looks like a cloud-synced folder (", p, "). ",
            "Check that your data agreements allow survey material to be stored there.",
            call. = FALSE)
  }
  invisible(p)
}

nets_slug <- function(x) {
  x |>
    str_to_lower() |>
    str_replace_all("[^a-z0-9]+", "-") |>
    str_replace_all("^-+|-+$", "")
}

# ---- Survey manifest ------------------------------------------------------------------

nets_report_statuses <- c("draft", "final-uncleared", "cleared", "published")
nets_context_policies <- c("standard", "aggregates-only", "local-only")
nets_clearance_statuses <- c("cleared", "pending", "refused", "not_required")
nets_area_types <- c("eez", "high_seas", "joint_zone", "other")

nets_read_manifest <- function(survey_dir) {
  nets_assert_local_session()
  f <- file.path(survey_dir, "survey.yaml")
  if (!file.exists(f)) {
    stop("No survey.yaml in ", survey_dir, ". Create the survey with nets_new_survey.R first.",
         call. = FALSE)
  }
  m <- yaml::read_yaml(f)
  if (length(m$reporting)) names(m$reporting) <- str_to_upper(names(m$reporting))
  problems <- nets_validate_manifest(m)
  if (length(problems)) {
    stop("survey.yaml has problems:\n- ", paste(problems, collapse = "\n- "), call. = FALSE)
  }
  m
}

nets_validate_manifest <- function(m) {
  p <- character()
  if (is.null(m$survey_id) || !nzchar(m$survey_id)) p <- c(p, "survey_id is missing")
  if (!isTRUE(m$report_status %in% nets_report_statuses)) {
    p <- c(p, paste0("report_status must be one of: ", paste(nets_report_statuses, collapse = ", ")))
  }
  if (!isTRUE(m$context_policy %in% nets_context_policies)) {
    p <- c(p, paste0("context_policy must be one of: ", paste(nets_context_policies, collapse = ", ")))
  }
  area_ids <- map_chr(m$areas %||% list(), ~ .x$id %||% NA_character_)
  if (!length(area_ids)) p <- c(p, "areas: list at least one area (EEZ, high-seas area, ...)")
  if (anyNA(area_ids) || anyDuplicated(area_ids)) p <- c(p, "areas: every area needs a unique id")
  for (a in m$areas %||% list()) {
    if (!isTRUE(a$type %in% nets_area_types)) {
      p <- c(p, paste0("area ", a$id, ": type must be one of ", paste(nets_area_types, collapse = ", ")))
    }
  }
  for (body in names(m$reporting %||% list())) {
    cl <- m$reporting[[body]]$clearance %||% list()
    unknown <- setdiff(names(cl), area_ids)
    if (length(unknown)) {
      p <- c(p, paste0("reporting$", body, "$clearance refers to unknown area id(s): ",
                       paste(unknown, collapse = ", ")))
    }
    for (a in names(cl)) {
      st <- cl[[a]]$status %||% NA
      if (!isTRUE(st %in% nets_clearance_statuses)) {
        p <- c(p, paste0("reporting$", body, "$clearance$", a, "$status must be one of ",
                         paste(nets_clearance_statuses, collapse = ", ")))
      }
      if (identical(st, "not_required") && !nzchar(cl[[a]]$scope %||% "")) {
        p <- c(p, paste0("reporting$", body, "$clearance$", a,
                         ": 'not_required' needs a scope note explaining why"))
      }
    }
  }
  p
}

# One row per reporting body x area: who has cleared what. Areas without an entry for a
# body are "missing", which the release check treats like "pending".
nets_clearance <- function(m) {
  areas <- map_dfr(m$areas, ~ tibble(
    area_id = .x$id, area_name = .x$name %||% .x$id, area_type = .x$type,
    aliases = list(unlist(.x$aliases %||% list()))
  ))
  bodies <- names(m$reporting %||% list())
  if (!length(bodies)) return(tibble())
  map_dfr(bodies, function(b) {
    cl <- m$reporting[[b]]$clearance %||% list()
    areas |>
      mutate(
        body = str_to_upper(b),
        status = map_chr(area_id, ~ cl[[.x]]$status %||% "missing"),
        cleared_by = map_chr(area_id, ~ as.character(cl[[.x]]$by %||% "")),
        cleared_on = map_chr(area_id, ~ as.character(cl[[.x]]$date %||% "")),
        scope = map_chr(area_id, ~ as.character(cl[[.x]]$scope %||% ""))
      )
  }) |>
    relocate(body)
}

# Expand "3, 7-9" or c(3, "7-9") into integer page numbers.
nets_parse_pages <- function(x) {
  if (is.null(x) || !length(x)) return(integer())
  parts <- unlist(str_split(as.character(unlist(x)), ",")) |> str_trim()
  parts <- parts[nzchar(parts)]
  unlist(map(parts, function(s) {
    if (str_detect(s, "^\\d+\\s*-\\s*\\d+$")) {
      r <- as.integer(str_split(s, "\\s*-\\s*")[[1]])
      seq(r[1], r[2])
    } else {
      as.integer(s)
    }
  })) |> unique() |> sort()
}

# ---- Coordinate patterns --------------------------------------------------------------
#
# Survey reports write positions in many ways (English, French, Portuguese; with or without
# degree signs). These patterns aim at positions with sub-degree precision. Whole-degree
# mentions such as "21°N" usually describe survey extent and are kept by default.
# Temperatures ("24.5°C") are excluded. The patterns reduce risk; they cannot guarantee
# that every position is caught, which is why station listings are withheld page-wise too.

.deg <- "[\u00B0\u00BA\u02DA]"                    # degree sign and common look-alikes
.min <- "['\u2032\u2019\u00B4]"                   # minute marks
.sec <- "(?:\"|\u2033|\u201D|'')"                 # second marks
.hem <- "[NSEWO]"                                 # O = Oeste / Ouest
.hem_word <- "(?i:north|south|east|west|nord|sud|est|ouest|norte|sul|leste|oeste)"

nets_coord_regex <- c(
  # Degrees and minutes with a minute mark are a sub-degree position whatever follows
  # ("DD°MM' north", or "DD°MM'" alone in a caption); a spelled-out hemisphere is masked with it.
  deg_min_mark = paste0("(?<![\\d.,])\\d{1,3}\\s{0,2}", .deg, "\\s{0,2}\\d{1,2}(?:[.,]\\d+)?\\s{0,2}", .min,
                        "(?:\\s{0,2}\\d{1,2}(?:[.,]\\d+)?\\s{0,2}", .sec, ")?(?:\\s{0,2}(?:", .hem, "|", .hem_word, ")\\b)?"),
  deg_min_word = paste0("(?<![\\d.,])\\d{1,3}\\s{0,2}", .deg, "\\s{0,2}\\d{1,2}(?:[.,]\\d+)?\\s{1,2}", .hem_word, "\\b"),
  deg_min_sec = paste0("(?<![\\d.,])\\d{1,3}\\s{0,2}", .deg, "\\s{0,2}\\d{1,2}(?:[.,]\\d+)?\\s{0,2}(?:",
                       .min, "\\s{0,2})?(?:\\d{1,2}(?:[.,]\\d+)?\\s{0,2}", .sec, "\\s{0,2})?", .hem, "\\b"),
  hem_first   = paste0("\\b", .hem, "\\s{0,2}\\d{1,3}\\s{0,2}", .deg, "\\s{0,2}\\d{1,2}(?:[.,]\\d+)?(?:\\s{0,2}",
                       .min, ")?"),
  deg_min_nosign = paste0("(?<![\\d.,])\\d{1,3}[ -]\\d{1,2}[.,]\\d+\\s{0,2}", .hem, "\\b"),
  decimal_hem = paste0("(?<![\\d.,])-?\\d{1,3}[.,]\\d+\\s{0,2}", .deg, "?\\s{0,2}", .hem, "\\b"),
  decimal_deg = paste0("(?<![\\d.,])-?\\d{1,3}[.,]\\d+\\s{0,2}", .deg, "(?!\\s{0,2}[CFcf])")
)

nets_whole_degree_regex <- paste0("(?<![\\d.,])\\d{1,3}\\s{0,2}", .deg, "\\s{0,2}", .hem, "\\b")

# Mask coordinates in a character vector; returns the masked text and the number masked.
nets_redact_text <- function(text, keep_whole_degree = TRUE) {
  pats <- nets_coord_regex
  if (!keep_whole_degree) pats <- c(pats, whole_degree = nets_whole_degree_regex)
  n <- integer(length(text))
  for (p in pats) {
    n <- n + str_count(text, regex(p))
    text <- str_replace_all(text, regex(p), "[COORD]")
  }
  list(text = text, n = n)
}

nets_count_coords <- function(text, keep_whole_degree = TRUE) {
  nets_redact_text(text, keep_whole_degree)$n
}

# How strongly a page looks like a station/position listing. Explicit coordinates count
# one each; on pages with a latitude/longitude/position header, bare decimal numbers with
# three or more decimals count one per pair (tables often print positions without symbols).
nets_position_score <- function(text) {
  coords <- nets_count_coords(text)
  header <- str_detect(
    text,
    regex("\\b(lat(itude)?|lon(g|gitude)?|position|posi[c\u00E7][a\u00E3]o)\\b", ignore_case = TRUE)
  )
  bare <- str_count(text, "(?<![\\d.,])-?\\d{1,3}[.,]\\d{3,}(?!\\d)")
  as.integer(coords + ifelse(header, bare %/% 2, 0L))
}

# ---- Script location ------------------------------------------------------------------

# Remember where the scripts live so helpers can find VERSION and templates.
if (!exists(".nets_scripts_dir")) {
  .nets_scripts_dir <- local({
    d <- NULL
    for (i in rev(seq_len(sys.nframe()))) {
      of <- sys.frame(i)$ofile
      if (!is.null(of) && grepl("nets_common\\.R$", of)) {
        d <- dirname(normalizePath(of))
        break
      }
    }
    if (is.null(d)) {
      cfg <- nets_read_config()
      d <- if (!is.null(cfg$nets_path)) file.path(cfg$nets_path, "scripts") else getwd()
    }
    d
  })
}
