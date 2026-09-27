# test_nets.R — end-to-end tests of the NETS scripts on SYNTHETIC material.
#
# Run from anywhere:  Rscript nets/tests/test_nets.R
#
# Everything is generated at run time in a temporary folder: a fake survey report PDF,
# fake StoX outputs and a fake evidence log. All positions and values below are invented
# for testing and describe no real station or catch.
#
# nets:allow-synthetic

self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
nets_root_dir <- normalizePath(file.path(dirname(self), ".."))
for (s in c("nets_common.R", "nets_evidence.R", "nets_new_survey.R", "nets_ingest_pdf.R",
            "nets_stox.R", "nets_release_check.R", "nets_new_synthesis.R")) {
  source(file.path(nets_root_dir, "scripts", s))
}

passed <- 0L
check <- function(desc, ok) {
  if (!isTRUE(ok)) stop("FAILED: ", desc, call. = FALSE)
  passed <<- passed + 1L
  cat("ok -", desc, "\n")
}
expect_error <- function(desc, expr, pattern = NULL) {
  err <- tryCatch({ force(expr); NULL }, error = function(e) conditionMessage(e))
  check(desc, !is.null(err) && (is.null(pattern) || grepl(pattern, err)))
}

ws <- file.path(tempfile("nets-test-"), "workspace")
dir.create(ws, recursive = TRUE)

# ---- Coordinate patterns ------------------------------------------------------------
# nets:allow-synthetic (all positions below are invented)
masked <- c("14\u00B030.5'N", "017\u00B0 15' W", "12\u00B030'15\"S", "14 30.52 N", "N 14\u00B030'",
            "-17.2543\u00B0", "14.52\u00B0N", "12\u00B030'O")
kept <- c("between 12\u00B0N and 16\u00B0N", "surface temperature 24.5\u00B0C", "biomass 412 000 t",
          "CV 0.21", "length 23.5 cm", "Table 3.2 Numbers")
check("sub-degree positions are masked", all(nets_count_coords(masked) >= 1))
check("whole degrees, temperatures and ordinary numbers are kept", all(nets_count_coords(kept) == 0))
check("whole degrees are masked when asked", nets_count_coords("21\u00B0N", keep_whole_degree = FALSE) == 1)
check("page ranges parse", identical(nets_parse_pages(c("3", "7-9, 12")), c(3L, 7L, 8L, 9L, 12L)))

# ---- Workspace safety ---------------------------------------------------------------
repo_dir <- file.path(tempfile("nets-repo-"))
dir.create(file.path(repo_dir, ".git"), recursive = TRUE)
expect_error("workspace inside a git repository is refused",
             nets_assert_safe_workspace(file.path(repo_dir, "ws")), "git repository")
expect_error("workspace at filesystem root is refused", nets_assert_safe_workspace("/"), "root")

# ---- New survey and manifest --------------------------------------------------------
sd <- nets_new_survey("TEST-2026", ws)
check("survey folders are created",
      all(dir.exists(file.path(sd, c("sources/reports", "sources/stox", "local", "context", "evidence", "outputs")))))
check("agent read policy is written", file.exists(file.path(sd, "AGENT-READ-POLICY.md")))
cfg <- tempfile(fileext = ".json")
jsonlite::write_json(list(default_context_policy = "aggregates-only"), cfg, auto_unbox = TRUE)
Sys.setenv(NETS_CONFIG = cfg)
sd_cons <- nets_new_survey("TEST-CONSERVATIVE", ws)
Sys.unsetenv("NETS_CONFIG")
check("install-time default context policy carries into new surveys",
      any(readLines(file.path(sd_cons, "survey.yaml")) == "context_policy: aggregates-only"))
expect_error("existing survey is not overwritten", nets_new_survey("TEST-2026", ws), "already exists")
expect_error("template manifest is rejected until areas are real", {
  m <- yaml::read_yaml(file.path(sd, "survey.yaml")); m$reporting$CECAF$clearance$AAA$status <- "maybe"
  yaml::write_yaml(m, file.path(sd, "survey.yaml")); nets_read_manifest(sd)
}, "status must be one of")

manifest <- list(
  survey_id = "TEST-2026", title = "Synthetic pelagic survey", vessel = "Dr. Fridtjof Nansen",
  report_status = "final-uncleared", context_policy = "standard",
  areas = list(
    list(id = "AAA", name = "Alphaland", aliases = list("Alphalande"), type = "eez", data_owner = "Alpha institute"),
    list(id = "BBB", name = "Betaland", aliases = list("Betalandia"), type = "eez", data_owner = "Beta institute"),
    list(id = "HS1", name = "High seas block", type = "high_seas", data_owner = "Programme")
  ),
  reporting = list(
    cecaf = list(meeting = "Synthetic working group 2026", language = "en", due = "2099-01-01",
                 clearance = list(
                   AAA = list(status = "cleared", by = "AI", date = "2026-09-01", scope = "all"),
                   BBB = list(status = "pending", by = "", date = "", scope = ""),
                   HS1 = list(status = "not_required", by = "PM", date = "2026-09-01", scope = "high seas, programme decision")
                 ))
  ),
  redaction = list(keep_whole_degree_mentions = TRUE, withhold_threshold = 6L,
                   withhold_pages = list(`report.pdf` = list("5")))
)
yaml::write_yaml(manifest, file.path(sd, "survey.yaml"))
m <- nets_read_manifest(sd)
check("body names are normalised to upper case", "CECAF" %in% names(m$reporting))
cl <- nets_clearance(m)
check("clearance table has one row per body x area", nrow(cl) == 3 && all(cl$body == "CECAF"))

# ---- PDF ingestion ------------------------------------------------------------------
pdf_file <- file.path(sd, "sources", "reports", "report.pdf")
write_page <- function(lines) {
  plot.new()
  for (i in seq_along(lines)) text(0, 1 - i * 0.035, lines[i], adj = 0, family = "mono", cex = 0.7)
}
grDevices::pdf(pdf_file, width = 8.3, height = 11.7, encoding = "ISOLatin1")
write_page(c("1 INTRODUCTION",
             "The survey covered the shelf between 12\u00B0N and 16\u00B0N.",
             "A dense school was recorded at 14\u00B030.5'N 017\u00B015.2'W.",
             "Surface temperature ranged from 21.0\u00B0C to 24.5\u00B0C."))
write_page(c("Table 3. Acoustic biomass by region (tonnes)",
             "Region        Sardinella   Horse mackerel",
             "North           412000         98000",
             "South           120000         45000"))
write_page(c("Annex 1. Station list",
             "St   Lat        Lon",
             sprintf("%-4d %d\u00B0%02d.%d'N  %03d\u00B0%02d.%d'W", 1:12, 13, 10 + 1:12, 1:12 %% 10, 17, 20 + 1:12, 1:12 %% 10)))
write_page(character())
write_page(c("2 METHODS", "Nothing positional here, but withheld by the manifest."))
invisible(grDevices::dev.off())

reg <- nets_ingest_reports(sd)
ctx <- readLines(file.path(sd, "context", "report.md"))
full <- readLines(file.path(sd, "local", "report", "fulltext.md"))
lg <- read_csv(file.path(sd, "context", "redaction-log.csv"), show_col_types = FALSE)
check("full text keeps the original position locally", any(str_detect(full, "14\u00B030.5'N")))
check("context copy masks the position", !any(str_detect(ctx, "14\u00B030.5'N")) && any(str_detect(ctx, fixed("[COORD]"))))
check("context copy keeps whole-degree extent", any(str_detect(ctx, "12\u00B0N and 16\u00B0N")))
check("context copy keeps temperatures", any(str_detect(ctx, fixed("24.5\u00B0C"))))
check("context copy keeps aggregate tables", any(str_detect(ctx, "412000")))
check("station listing page is withheld", isTRUE(lg$withheld[lg$page == 3]) &&
        !any(str_detect(ctx, "13\u00B011")))
check("manually listed page is withheld", isTRUE(lg$withheld[lg$page == 5]))
check("empty page is flagged as without text", any(str_detect(ctx, "No text layer")))
idx <- readLines(file.path(sd, "context", "report.index.md"))
check("index lists captions", any(str_detect(idx, "Table 3")))
check("register records checksum", nrow(reg) == 1 && nchar(reg$md5) == 32)
msgs <- character()
withCallingHandlers(nets_ingest_reports(sd), message = function(e) { msgs <<- c(msgs, conditionMessage(e)); invokeRestart("muffleMessage") })
check("unchanged PDFs are skipped", any(str_detect(msgs, "Unchanged, skipped")))

# ---- StoX outputs -------------------------------------------------------------------
stox <- file.path(sd, "sources", "stox", "proj")
dir.create(file.path(stox, "output", "report", "ReportBootstrap"), recursive = TRUE)
dir.create(file.path(stox, "output", "baseline", "SuperIndividuals"), recursive = TRUE)
dir.create(file.path(stox, "input", "biotic"), recursive = TRUE)
set.seed(1)
agg <- tidyr::expand_grid(Stratum = c("S1", "S2"), SpeciesCategory = c("sardinella", "horse mackerel"),
                          IndividualTotalLength = seq(10, 30, 5)) |>
  mutate(Mean = round(runif(n(), 1, 100), 1), SD = round(Mean * 0.2, 1), CV = 0.2)
write_tsv(agg, file.path(stox, "output", "report", "ReportBootstrap", "ReportBootstrap.txt"))
det <- tibble(Haul = rep(1:6, each = 5), Latitude = 14 + Haul / 10, Longitude = -17 - Haul / 10,
              Stratum = rep(c("S1", "S2"), each = 15), SpeciesCategory = "sardinella",
              IndividualTotalLength = rep(seq(10, 30, 5), 6), Abundance = runif(30, 0, 1e5),
              Biomass = Abundance * 0.1)
write_tsv(det, file.path(stox, "output", "baseline", "SuperIndividuals", "SuperIndividuals.txt"))
saveRDS(list(Station = det[, c("Haul", "Latitude", "Longitude")], Summary = agg[1:3, ]),
        file.path(stox, "output", "baseline", "StoxBiotic.rds"))
write_tsv(det, file.path(stox, "input", "biotic", "raw.txt"))

inv <- nets_stox_inventory(sd)
check("input folder is ignored", !any(str_detect(inv$file, "input")))
check("aggregate report is classified aggregate", inv$tier[str_detect(inv$file, "ReportBootstrap")] == "aggregate")
check("super-individual table is classified detail", inv$tier[str_detect(inv$file, "SuperIndividuals")] == "detail")
check("tables inside rds lists are inventoried", sum(str_detect(inv$file, "StoxBiotic")) == 2)
inv_md <- readLines(file.path(sd, "context", "stox-inventory.md"))
check("inventory holds no values", !any(str_detect(inv_md, "14\\.1")))

si <- file.path(stox, "output", "baseline", "SuperIndividuals", "SuperIndividuals.txt")
out <- nets_stox_summarise(si, sd, "biomass_by_stratum", group_by = c("Stratum", "SpeciesCategory"),
                           sum_cols = c("Abundance", "Biomass"), IndividualTotalLength >= 15)
s <- read_csv(out, show_col_types = FALSE)
check("summary is aggregated to strata", nrow(s) == 2 && all(c("n_rows", "rows_with_missing") %in% names(s)))
check("summary applies filters", all(s$n_rows == 12))
check("summary has provenance", file.exists(file.path(sd, "context", "stox-summaries", "biomass_by_stratum.provenance.txt")))
expect_error("grouping by haul is refused",
             nets_stox_summarise(si, sd, "x", group_by = "Haul", sum_cols = "Biomass"), "station/position")
expect_error("exporting a detail table is refused", nets_stox_export(si, sd, "x"), "detail table")
rb <- file.path(stox, "output", "report", "ReportBootstrap", "ReportBootstrap.txt")
nets_stox_export(rb, sd, "bootstrap_sardinella", SpeciesCategory == "sardinella")
check("aggregate export works", nrow(read_csv(file.path(sd, "context", "stox-summaries", "bootstrap_sardinella.csv"),
                                              show_col_types = FALSE)) == 10)

# ---- Evidence log -------------------------------------------------------------------
ev_rows <- tribble(
  ~id, ~claim, ~value, ~unit, ~uncertainty, ~uncertainty_type, ~species_or_group, ~area_id, ~period,
  ~source_doc, ~page, ~locator, ~source_type, ~evidence_class, ~derivation, ~sensitivity,
  ~entered_by, ~verified_by, ~notes,
  "E001", "Acoustic biomass, North", "412000", "tonnes", "0.21", "CV", "Sardinella", "AAA", "2026",
  "report.pdf", "2", "Table 3", "report", "reported", "", "restricted", "agent", "NN", "",
  "E002", "Acoustic biomass, South", "120000", "tonnes", "", "none reported", "Sardinella", "BBB", "2026",
  "report.pdf", "2", "Table 3", "report", "reported", "", "restricted", "agent", "", "",
  "E003", "Total acoustic biomass", "532000", "tonnes", "", "none reported", "Sardinella", "ALL", "2026",
  "report.pdf", "2", "Table 3", "report", "derived", "E001 + E002", "restricted", "agent", "NN", "",
  "E004", "Position of dense school", "masked", "", "", "", "Sardinella", "AAA", "2026",
  "report.pdf", "1", "Section 1", "report", "reported", "", "sensitive", "agent", "NN", ""
)
ev_path <- file.path(sd, "evidence", "evidence-log.csv")
write_csv(ev_rows, ev_path, na = "")
ev <- nets_ev_load(ev_path, m)
check("value is formatted with unit", nets_ev_value(ev, "E001") == "412,000 tonnes")
check("uncertainty can be appended", nets_ev_value(ev, "E001", uncertainty = TRUE) == "412,000 tonnes (CV 0.21)")
check("citation names page and table", nets_ev_cite(ev, "E001") == "(report.pdf, p. 2, Table 3)")
check("derived citation says so", str_detect(nets_ev_cite(ev, "E003"), "^\\(derived from"))
check("annex excludes sensitive entries", !"E004" %in% nets_ev_annex(ev, c("E001", "E004"))$ID)
bad <- mutate(ev_rows, derivation = if_else(id == "E003", "", derivation))
write_csv(bad, file.path(sd, "evidence", "bad.csv"), na = "")
expect_error("derived value without derivation is rejected",
             nets_ev_load(file.path(sd, "evidence", "bad.csv")), "derivation")

# ---- Synthesis draft and release check ----------------------------------------------
draft <- nets_new_synthesis(sd, "cecaf", "Synthetic Author")
check("draft is created under outputs/CECAF", file.exists(draft) && basename(dirname(draft)) == "CECAF")
expect_error("second draft is not overwritten", nets_new_synthesis(sd, "CECAF"), "already exists")
expect_error("draft for a body without a reporting entry is refused", nets_new_synthesis(sd, "SEAFO"), "no reporting entry")

txt <- readLines(draft)
found <- which(txt == "# What the survey found")
body_ok <- c(txt[1:found], "",
             "In Alphaland the acoustic biomass of sardinella was `r v(\"E001\")` `r cite(\"E001\")`.", "",
             txt[(found + 1):length(txt)])
body_ok <- str_replace(body_ok, fixed("used_ids <- character()"), "used_ids <- c(\"E001\")")
writeLines(body_ok, draft)

# The template must knit (qmd chunks are plain knitr chunks).
env <- new.env()
env$params <- list(survey_dir = sd, body = "CECAF", nets_path = nets_root_dir)
md <- file.path(dirname(draft), "knit-test.md")
invisible(suppressMessages(knitr::knit(draft, md, envir = env, quiet = TRUE)))
knitted <- readLines(md)
check("template knits and pulls values from the evidence log", any(str_detect(knitted, fixed("412,000 tonnes (report.pdf, p. 2, Table 3)"))))
check("clearance statement names cleared and pending areas",
      any(str_detect(knitted, "Alphaland")) && any(str_detect(knitted, "Results for Betaland are not included in this synthesis")))
check("evidence annex is rendered", any(str_detect(knitted, "E001.*Acoustic biomass, North")))
invisible(file.remove(md))

r <- nets_release_check(sd, "CECAF", draft)
check("clean draft passes with warnings only", r$verdict == "PASS WITH WARNINGS")
check("uncleared report status is flagged", "report status" %in% r$findings$check)
check("release check report is written", file.exists(file.path(sd, "outputs", "CECAF", "release-check.md")))

writeLines(c(body_ok, "Betaland had `r v(\"E002\")`.", "A school at 14\u00B030.5'N.",
             "Sensitive `r v(\"E004\")`.", "Unknown `r v(\"E999\")`.", "The total was 532,000 tonnes."), draft)
r2 <- nets_release_check(sd, "CECAF", draft, write = FALSE)
f <- r2$findings
check("problem draft fails", r2$verdict == "FAIL")
check("uncleared evidence fails", any(f$level == "FAIL" & f$check == "clearance"))
check("coordinates fail", any(f$level == "FAIL" & f$check == "coordinates"))
check("sensitive evidence fails", any(f$level == "FAIL" & f$check == "sensitivity"))
check("unknown evidence id fails", any(f$level == "FAIL" & f$check == "evidence"))
check("uncleared area named in text is flagged", any(f$check == "uncleared area named"))
check("unverified evidence warns", any(f$level == "WARN" & f$check == "verification"))
check("hard-coded number warns", any(f$check == "hard-coded numbers"))

html <- file.path(dirname(draft), "out.html")
writeLines("<html><body><p>Position 14&deg;30.5'N</p><p>DRAFT</p></body></html>", html)
r3 <- nets_release_check(sd, "CECAF", html, write = FALSE)
check("rendered html is scanned", any(r3$findings$check == "coordinates") && any(r3$findings$check == "markings"))

m_lo <- manifest; m_lo$context_policy <- "local-only"
yaml::write_yaml(m_lo, file.path(sd, "survey.yaml"))
expect_error("local-only survey refuses a cloud-drafted synthesis", nets_new_synthesis(sd, "CECAF", ""), "local-only")

cat("\nAll", passed, "checks passed.\n")
