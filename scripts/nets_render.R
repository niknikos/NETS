# nets_render.R — render a synthesis or slide deck to Word, HTML, HTML slides or PowerPoint.
#
# Usage:
#   Rscript nets_render.R <file.qmd> [--to docx|html|revealjs|pptx] [--engine auto|quarto|rmarkdown]
#
# Default --to: docx for a synthesis, revealjs (HTML slides) for a *_slides.qmd deck.
#
# Quarto is used when it is installed (on PATH, QUARTO_PATH, quarto_path in
# ~/.nets/config.json, or the copy bundled with RStudio). Quarto's HTML formats compile
# their theme through a small script it writes to the temporary folder; where group policy
# forbids running programs from user folders, that step fails ("blocked by group policy").
# With --engine auto, HTML output then falls back to R's rmarkdown, which calls pandoc
# directly: html -> a self-contained HTML document; revealjs -> a self-contained reveal.js
# deck (package revealjs) or, without it, an ioslides deck. Every HTML file is
# self-contained: nothing is loaded from the internet when it is opened.
#
# Run the release check on the rendered file(s) as well as on the .qmd.

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

nets_render_formats <- c("docx", "html", "revealjs", "pptx")

nets_find_quarto <- function() {
  cands <- c(nets_read_config()$quarto_path %||% "", Sys.getenv("QUARTO_PATH"), Sys.which("quarto"))
  if (.Platform$OS.type == "windows") {
    pf <- c(Sys.getenv("ProgramFiles"), Sys.getenv("ProgramFiles(x86)"), file.path(Sys.getenv("LOCALAPPDATA"), "Programs"))
    cands <- c(cands, file.path(pf, "Quarto", "bin", "quarto.exe"),
               file.path(pf, "RStudio", "resources", "app", "bin", "quarto", "bin", "quarto.exe"),
               file.path(pf, "Positron", "resources", "app", "quarto", "bin", "quarto.exe"))
  } else {
    cands <- c(cands, "/usr/local/bin/quarto", "/opt/quarto/bin/quarto", "/Applications/quarto/bin/quarto",
               "/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto",
               "/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto")
  }
  cands <- cands[nzchar(cands) & file.exists(cands)]
  if (length(cands)) normalizePath(cands[1]) else ""
}

# pandoc for rmarkdown: RSTUDIO_PANDOC if set, else the copy next to Quarto, else PATH.
nets_find_pandoc_dir <- function(quarto = nets_find_quarto()) {
  if (nzchar(Sys.getenv("RSTUDIO_PANDOC"))) return(Sys.getenv("RSTUDIO_PANDOC"))
  exe <- if (.Platform$OS.type == "windows") "pandoc.exe" else "pandoc"
  if (nzchar(quarto)) {
    tools <- file.path(dirname(quarto), "tools")
    for (d in c(tools, file.path(tools, "x86_64"), file.path(tools, "aarch64"))) {
      if (file.exists(file.path(d, exe))) return(normalizePath(d))
    }
  }
  p <- Sys.which("pandoc")
  if (nzchar(p)) dirname(p) else ""
}

nets_render_quarto <- function(file, to, quarto, params = NULL) {
  old <- Sys.getenv("QUARTO_R", unset = NA)
  Sys.setenv(QUARTO_R = R.home("bin"))
  on.exit(if (is.na(old)) Sys.unsetenv("QUARTO_R") else Sys.setenv(QUARTO_R = old))
  owd <- setwd(dirname(file))
  on.exit(setwd(owd), add = TRUE)
  p_args <- unlist(map2(names(params), params, ~ c("-P", shQuote(paste0(.x, ":", .y)))))
  out <- suppressWarnings(system2(quarto, c("render", shQuote(basename(file)), "--to", to, p_args),
                                  stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status") %||% 0L
  list(ok = status == 0, log = out)
}

nets_render_rmarkdown <- function(file, to, params = NULL) {
  if (!requireNamespace("rmarkdown", quietly = TRUE)) stop("Package rmarkdown is needed.", call. = FALSE)
  pd <- nets_find_pandoc_dir()
  if (!nzchar(pd)) stop("pandoc not found: install Quarto or RStudio, or set RSTUDIO_PANDOC.", call. = FALSE)
  Sys.setenv(RSTUDIO_PANDOC = pd)
  fmt <- switch(to,
    html = rmarkdown::html_document(self_contained = TRUE, toc = TRUE),
    revealjs = if (requireNamespace("revealjs", quietly = TRUE)) {
      revealjs::revealjs_presentation(self_contained = TRUE, center = FALSE, slide_level = 2,
                                      reveal_options = list(slideNumber = TRUE))
    } else {
      message("Package revealjs not installed; rendering an ioslides deck instead (install.packages(\"revealjs\")).")
      rmarkdown::ioslides_presentation(self_contained = TRUE)
    },
    docx = rmarkdown::word_document(),
    pptx = rmarkdown::powerpoint_presentation()
  )
  # Quarto's `execute:` options and `date: today` are Quarto features; set their effect here.
  fmt$knitr$opts_chunk <- utils::modifyList(fmt$knitr$opts_chunk %||% list(),
                                            list(echo = FALSE, warning = FALSE, message = FALSE))
  fmt$pandoc$args <- c(fmt$pandoc$args, "--metadata", paste0("date=", format(Sys.Date())))
  ext <- if (to %in% c("html", "revealjs")) "html" else to
  out <- paste0(tools::file_path_sans_ext(basename(file)), ".", ext)
  rmarkdown::render(file, output_format = fmt, output_file = out, output_dir = dirname(file),
                    params = params, envir = new.env(parent = globalenv()), quiet = TRUE)
}

# params: optional named list overriding the document's params (e.g. list(nets_path = ...)).
nets_render <- function(file, to = NULL, engine = c("auto", "quarto", "rmarkdown"), params = NULL) {
  engine <- match.arg(engine)
  file <- normalizePath(file, mustWork = TRUE)
  to <- to %||% if (grepl("_slides\\.qmd$", file)) "revealjs" else "docx"
  if (!to %in% nets_render_formats) stop("--to must be one of: ", paste(nets_render_formats, collapse = ", "), call. = FALSE)
  ext <- if (to %in% c("html", "revealjs")) "html" else to
  target <- file.path(dirname(file), paste0(tools::file_path_sans_ext(basename(file)), ".", ext))

  quarto <- if (engine == "rmarkdown") "" else nets_find_quarto()
  if (engine == "quarto" && !nzchar(quarto)) stop("Quarto not found. Install it, or use --engine rmarkdown.", call. = FALSE)
  if (nzchar(quarto)) {
    r <- nets_render_quarto(file, to, quarto, params)
    if (r$ok && file.exists(target)) {
      message("Rendered with Quarto: ", target)
      return(invisible(target))
    }
    blocked <- any(grepl("blocked by group policy|Theme file compilation failed", r$log, ignore.case = TRUE))
    if (engine == "quarto" || !to %in% c("html", "revealjs")) {
      stop("Quarto could not render ", basename(file), ":\n", paste(tail(r$log, 8), collapse = "\n"), call. = FALSE)
    }
    message(if (blocked) "Quarto could not compile its HTML theme (usually group policy blocking scripts in user folders); " else
      "Quarto could not render HTML; ", "using rmarkdown instead.")
  }
  out <- nets_render_rmarkdown(file, to, params)
  message("Rendered with rmarkdown: ", out)
  invisible(out)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  opt <- function(flag) { i <- match(flag, args); if (is.na(i) || i == length(args)) NULL else args[i + 1] }
  if (!length(args) || args[1] %in% c("-h", "--help")) {
    cat("Usage: Rscript nets_render.R <file.qmd> [--to docx|html|revealjs|pptx] [--engine auto|quarto|rmarkdown]\n")
    quit(status = if (length(args)) 0 else 1)
  }
  nets_render(args[1], opt("--to"), opt("--engine") %||% "auto")
}
