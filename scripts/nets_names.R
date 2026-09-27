# nets_names.R — naming countries and sensitive places as agreed.
#
# Reads nets-knowledge/country-names.yaml (the programme's register of country names,
# forms to avoid and sensitive place names) and checks text against it. A survey's
# survey.yaml overrides the register: area `name`s are what a synthesis prints, and
# `naming.agreed_terms` records wording the data owners agreed for sensitive places.
#
# Used by the release check; nothing here reads report content.

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

nets_names_register <- function(path = file.path(nets_root(), "nets-knowledge", "country-names.yaml")) {
  if (!file.exists(path)) return(list(countries = list(), features = list(), sensitive = list()))
  yaml::read_yaml(path)
}

nets_rx_escape <- function(x) str_replace_all(x, "([.\\\\|()\\[\\]{}^$*+?])", "\\\\\\1")

# Every name the register knows (all languages, accepted forms, geographic features).
nets_register_names <- function(reg) {
  cn <- unlist(map(reg$countries %||% list(), ~ c(.x$en, .x$fr, .x$pt, unlist(.x$also))))
  unique(c(cn, unlist(reg$features)))
}

# A name as a pattern: whole words, any whitespace (including a line break) between words.
.name_rx <- function(name) {
  words <- str_split(str_trim(name), "\\s+")[[1]]
  paste0("\\b", paste(map_chr(words, nets_rx_escape), collapse = "\\s+"), "\\b")
}

# Names are searched in the whole text, not line by line, so that a name broken across
# lines ("The" / "Gambia", "Western" / "Sahara") is still seen. Matches are mapped back to
# line numbers for the report.
.lines_at <- function(lines, positions) {
  starts <- cumsum(c(1L, nchar(lines) + 1L))[seq_along(lines)]
  sort(unique(findInterval(positions, starts)))
}

# Hide names that contain `name` as a whole word ("Guinea-Bissau", "Gulf of Guinea" for
# "Guinea"), so that a search for `name` finds only the name itself. The filler keeps the
# text length, so positions still map to the right lines.
nets_hide_longer_names <- function(text, name, candidates) {
  inner <- regex(.name_rx(name), ignore_case = TRUE)
  longer <- unique(candidates[nchar(candidates) > nchar(name) & str_detect(candidates, inner)])
  longer <- longer[order(-nchar(longer))]
  for (l in longer) {
    text <- str_replace_all(text, regex(.name_rx(l), ignore_case = TRUE), function(m) strrep("‖", nchar(m)))
  }
  text
}

# Lines (indices) that mention any of `names`, ignoring longer names that contain them.
nets_lines_naming <- function(lines, names, candidates) {
  names <- unique(names[nzchar(names)])
  if (!length(lines) || !length(names)) return(integer())
  joined <- paste(lines, collapse = "\n")
  pos <- integer()
  for (nm in names) {
    masked <- nets_hide_longer_names(joined, nm, candidates)
    pos <- c(pos, str_locate_all(masked, regex(.name_rx(nm), ignore_case = TRUE))[[1]][, "start"])
  }
  .lines_at(lines, pos)
}

.avoid_regex <- function(a) {
  if (!is.null(a$pattern)) regex(a$pattern) else regex(.name_rx(a$text), ignore_case = TRUE)
}

.lines_matching <- function(lines, rx) {
  if (!length(lines)) return(integer())
  .lines_at(lines, str_locate_all(paste(lines, collapse = "\n"), rx)[[1]][, "start"])
}

# Findings for one file's lines: forms to avoid and sensitive terms.
#   agreed      character vector of terms the data owners agreed (survey.yaml naming.agreed_terms)
#   extra_avoid list of extra `avoid` entries from survey.yaml (same shape as the register's)
nets_naming_findings <- function(lines, fname, reg = nets_names_register(), agreed = character(),
                                 extra_avoid = list()) {
  out <- list()
  add <- function(level, check, detail, idx) {
    out[[length(out) + 1]] <<- tibble(level = level, check = check, detail = detail,
                                      where = paste0(fname, ":", paste(head(idx, 5), collapse = ",")))
  }
  avoid <- c(unlist(map(reg$countries %||% list(), ~ .x$avoid %||% list()), recursive = FALSE), extra_avoid)
  for (a in avoid) {
    idx <- .lines_matching(lines, .avoid_regex(a))
    if (length(idx)) {
      found <- if (!is.null(a$text)) paste0("\"", a$text, "\"") else "a form to avoid"
      add(str_to_upper(a$level %||% "warn"), "naming",
          paste0("Found ", found, "; write \"", a$say %||% "the agreed form", "\".",
                 if (!is.null(a$why)) paste0(" ", a$why) else ""), idx)
    }
  }
  agreed_l <- str_to_lower(str_trim(agreed))
  candidates <- nets_register_names(reg)
  for (s in reg$sensitive %||% list()) {
    terms <- unlist(s$terms)
    open <- terms[!str_to_lower(terms) %in% agreed_l]
    if (!length(open)) next
    idx <- nets_lines_naming(lines, open, c(candidates, terms))
    if (length(idx)) {
      found <- open[map_lgl(open, ~ length(nets_lines_naming(lines[idx], .x, c(candidates, terms))) > 0)]
      add(str_to_upper(s$level %||% "fail"), "sensitive name",
          paste0(paste(found, collapse = ", "), ": ", s$why %||% "sensitive name",
                 " Use only wording the data owners agreed, and record it under naming.agreed_terms in survey.yaml."), idx)
    }
  }
  bind_rows(out)
}

# Areas in survey.yaml whose id is an ISO 3166 alpha-3 code but whose name is not one of
# the register's forms for that country.
nets_area_name_findings <- function(clearance_rows, reg = nets_names_register()) {
  forms <- map(reg$countries %||% list(), ~ str_to_lower(c(.x$en, .x$fr, .x$pt, unlist(.x$also))))
  names(forms) <- map_chr(reg$countries %||% list(), "iso3")
  rows <- distinct(clearance_rows, area_id, area_name, .keep_all = TRUE)
  out <- list()
  for (i in seq_len(nrow(rows))) {
    f <- forms[[rows$area_id[i]]]
    if (is.null(f) || str_to_lower(rows$area_name[i]) %in% f) next
    reg_c <- keep(reg$countries, ~ identical(.x$iso3, rows$area_id[i]))[[1]]
    out[[length(out) + 1]] <- tibble(
      level = "WARN", check = "naming",
      detail = paste0("Area ", rows$area_id[i], " is named \"", rows$area_name[i], "\" in survey.yaml; the register ",
                      "uses \"", reg_c$en, "\" (fr \"", reg_c$fr, "\", pt \"", reg_c$pt, "\"). ",
                      "The clearance statement prints the survey.yaml name."),
      where = "survey.yaml"
    )
  }
  bind_rows(out)
}

# The form of a country's name for a language, for use in templates: nets_country("GMB", "fr").
nets_country <- function(iso3, lang = "en", reg = nets_names_register()) {
  c1 <- keep(reg$countries %||% list(), ~ identical(.x$iso3, iso3))
  if (!length(c1)) stop("Country not in the register: ", iso3, call. = FALSE)
  c1[[1]][[lang]] %||% c1[[1]]$en
}
