# nets_fetch_resourcespace.R — download survey reports from a ResourceSpace collection
# (e.g. IMR's document archive) into a NETS survey folder.
#
# Usage (on a machine inside the institute's network):
#   Rscript nets_fetch_resourcespace.R <survey_dir> --collection 124 --list    # what is there
#   Rscript nets_fetch_resourcespace.R <survey_dir> --collection 124           # download PDFs
#   Rscript nets_fetch_resourcespace.R <survey_dir> --collection 124 --refs 101,102   # only these
#   Rscript nets_fetch_resourcespace.R <survey_dir> --collection 124 --ext pdf,zip
#
# Uses ResourceSpace's API with a *signed* query: each request carries
# sha256(private key + query), so the key itself never crosses the network. The key is read
# from the operating system's credential store (keyring service "nets-resourcespace"), or
# from the NETS_RS_KEY environment variable. It is never written to the NETS config, never
# printed, and must never be typed into an agent chat. Set it yourself in an R console:
#
#   keyring::key_set("nets-resourcespace", username = "<your ResourceSpace user name>")
#
# Configuration in ~/.nets/config.json (no secrets):
#   "resourcespace": { "base_url": "https://<host>", "user": "<user name>" }
#
# Downloads go to sources/reports/ (PDF) or sources/stox/ (zip); both are folders agents
# never read. Only reference numbers, titles and counts are printed.

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

nets_rs_keyring_service <- "nets-resourcespace"

nets_rs_settings <- function(base_url = NULL, user = NULL) {
  cfg <- nets_read_config()$resourcespace %||% list()
  base_url <- base_url %||% cfg$base_url %||% Sys.getenv("NETS_RS_URL", unset = NA)
  user <- user %||% cfg$user %||% Sys.getenv("NETS_RS_USER", unset = NA)
  if (is.na(base_url) || !nzchar(base_url)) {
    stop("No ResourceSpace address. Add resourcespace$base_url to ", nets_config_path(),
         " (e.g. \"https://<host>\").", call. = FALSE)
  }
  if (is.na(user) || !nzchar(user)) {
    stop("No ResourceSpace user name. Add resourcespace$user to ", nets_config_path(), ".", call. = FALSE)
  }
  base_url <- sub("/+$", "", sub("/login\\.php.*$", "", base_url))
  if (startsWith(base_url, "http://")) {
    warning("ResourceSpace is addressed over plain http. The signed query protects your key, ",
            "but downloaded reports cross the network unencrypted. Use https if the server offers it.",
            call. = FALSE)
  }
  list(base_url = base_url, user = user)
}

# The private API key: environment variable first (for scheduled or non-interactive use),
# then the OS credential store. Never printed or returned to the console.
nets_rs_key <- function(user) {
  key <- Sys.getenv("NETS_RS_KEY", unset = "")
  if (nzchar(key)) return(key)
  if (requireNamespace("keyring", quietly = TRUE)) {
    key <- tryCatch(keyring::key_get(nets_rs_keyring_service, username = user), error = function(e) "")
    if (nzchar(key)) return(key)
  }
  stop("No ResourceSpace API key found for user '", user, "'. In your own R console (not in an ",
       "agent chat) run:\n  keyring::key_set(\"", nets_rs_keyring_service, "\", username = \"", user, "\")\n",
       "and paste the private API key from your ResourceSpace user profile when prompted.",
       call. = FALSE)
}

# Build the signed API URL for one call. Parameters are passed positionally (param1, ...),
# which ResourceSpace versions have accepted for a long time.
nets_rs_url <- function(settings, key, fn, params = list()) {
  enc <- function(x) utils::URLencode(as.character(x), reserved = TRUE)
  pars <- if (length(params)) paste0("&param", seq_along(params), "=", vapply(params, enc, ""), collapse = "") else ""
  query <- paste0("user=", enc(settings$user), "&function=", enc(fn), pars)
  sign <- as.character(openssl::sha256(paste0(key, query)))
  paste0(settings$base_url, "/api/?", query, "&sign=", sign)
}

# A connection failure explained in terms the user can act on. Only the address before
# /api/ is shown, never the query (it carries the signature).
nets_rs_connection_message <- function(msg, url) {
  base <- sub("/api/.*$", "", url)
  hint <- if (grepl("^https://", base)) {
    paste0(" If the server answers only on plain http, set base_url to ", sub("^https://", "http://", base),
           " in ", nets_config_path(), " (documents then cross the network unencrypted; the key stays protected),",
           " or download the reports yourself into sources/reports/.")
  } else ""
  reason <- if (grepl("resolve", msg, ignore.case = TRUE)) {
    "the server name could not be resolved: are you inside the institute's network or VPN?"
  } else if (grepl("timed? ?out|timeout", msg, ignore.case = TRUE)) {
    "the connection timed out"
  } else if (grepl("refused", msg, ignore.case = TRUE)) {
    "the connection was refused"
  } else if (grepl("ssl|certificate|tls", msg, ignore.case = TRUE)) {
    "the secure (https) connection failed"
  } else {
    sub("https?://\\S+", "<url>", msg)
  }
  paste0("Could not reach ResourceSpace at ", base, ": ", reason, ".", hint)
}

# Default transport. Error messages never include the URL (it carries the signature).
nets_rs_http_get <- function(url) {
  res <- tryCatch(curl::curl_fetch_memory(url),
                  error = function(e) stop(nets_rs_connection_message(conditionMessage(e), url), call. = FALSE))
  if (res$status_code != 200) stop("ResourceSpace returned HTTP ", res$status_code, call. = FALSE)
  rawToChar(res$content)
}
nets_rs_http_download <- function(url, dest) {
  h <- curl::new_handle(failonerror = TRUE)
  tryCatch(curl::curl_download(url, dest, handle = h, quiet = TRUE),
           error = function(e) stop("Download failed (", sub("https?://\\S+", "<url>", conditionMessage(e)), ")",
                                    call. = FALSE))
  invisible(dest)
}

nets_rs_call <- function(settings, key, fn, params = list(), http_get = nets_rs_http_get) {
  txt <- http_get(nets_rs_url(settings, key, fn, params))
  if (grepl("^\\s*Invalid signature", txt)) {
    stop("ResourceSpace rejected the signature: check the user name and the stored API key.", call. = FALSE)
  }
  out <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = TRUE), error = function(e) NULL)
  if (is.null(out) && nzchar(trimws(txt))) {
    stop("Unexpected response from ResourceSpace function ", fn, " (not JSON).", call. = FALSE)
  }
  out
}

# Resources in a collection: reference, file extension and a title if one is present.
nets_rs_collection <- function(collection, settings, key, http_get = nets_rs_http_get) {
  res <- nets_rs_call(settings, key, "do_search", list(paste0("!collection", collection)), http_get)
  if (is.null(res) || !length(res) || (is.data.frame(res) && !nrow(res))) {
    return(tibble(ref = character(), extension = character(), title = character()))
  }
  res <- as_tibble(res)
  title_col <- intersect(c("field8", "title", "name"), names(res))[1]
  tibble(
    ref = as.character(res$ref),
    extension = str_to_lower(as.character(res$file_extension %||% NA_character_)),
    title = if (!is.na(title_col)) as.character(res[[title_col]]) else NA_character_
  )
}

nets_rs_fetch <- function(survey_dir, collection, ext = "pdf", refs = NULL, list_only = FALSE,
                          base_url = NULL, user = NULL,
                          http_get = nets_rs_http_get, http_download = nets_rs_http_download) {
  m <- nets_read_manifest(survey_dir)   # confirms this is a NETS survey folder
  settings <- nets_rs_settings(base_url, user)
  key <- nets_rs_key(settings$user)
  items <- nets_rs_collection(collection, settings, key, http_get)
  message("Collection ", collection, ": ", nrow(items), " resource(s).")
  if (list_only || !nrow(items)) {
    if (nrow(items)) print(as.data.frame(items), right = FALSE, row.names = FALSE)
    return(invisible(items))
  }

  ext <- str_to_lower(ext)
  if (!is.null(refs)) {
    unknown <- setdiff(as.character(refs), items$ref)
    if (length(unknown)) stop("Not in collection ", collection, ": ", paste(unknown, collapse = ", "), call. = FALSE)
    items <- filter(items, ref %in% as.character(refs))
  }
  wanted <- filter(items, extension %in% ext)
  skipped <- nrow(items) - nrow(wanted)
  if (skipped) message("Skipping ", skipped, " resource(s) with other file types (use --ext to include them).")

  reg_file <- file.path(survey_dir, "sources", "resourcespace.csv")
  reg <- if (file.exists(reg_file)) read_csv(reg_file, col_types = cols(.default = "c"), show_col_types = FALSE) else NULL

  new_rows <- list()
  for (i in seq_len(nrow(wanted))) {
    r <- wanted[i, ]
    sub_dir <- if (r$extension == "pdf") "reports" else "stox"
    stem <- nets_slug(if (!is.na(r$title) && nzchar(r$title)) r$title else "resource") |> str_trunc(60, ellipsis = "")
    fname <- paste0("rs", r$ref, "_", stem, ".", r$extension)
    dest <- file.path(survey_dir, "sources", sub_dir, fname)
    if (!is.null(reg) && any(reg$ref == r$ref & reg$collection == as.character(collection)) && file.exists(dest)) {
      message("Already downloaded: ", fname)
      next
    }
    # getfilepath = 0 returns a download URL; size "" = the original file.
    path_url <- nets_rs_call(settings, key, "get_resource_path", list(r$ref, 0, "", 0, r$extension), http_get)
    if (!is.character(path_url) || !nzchar(path_url)) {
      message("No download address for resource ", r$ref, "; skipped.")
      next
    }
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    http_download(path_url, dest)
    new_rows[[length(new_rows) + 1]] <- tibble(
      ref = r$ref, collection = as.character(collection), title = r$title %|NA|% "",
      extension = r$extension, file = file.path("sources", sub_dir, fname),
      md5 = unname(tools::md5sum(dest)), downloaded_on = as.character(Sys.Date())
    )
    message("Downloaded: ", fname)
  }
  if (length(new_rows)) {
    reg <- bind_rows(reg, bind_rows(new_rows) |> mutate(across(everything(), as.character))) |>
      distinct(ref, collection, .keep_all = TRUE)
    write_csv(reg, reg_file)
  }
  message(length(new_rows), " new file(s). Next: Rscript nets_ingest_pdf.R \"", survey_dir, "\"")
  invisible(bind_rows(new_rows))
}

`%|NA|%` <- function(x, y) if (is.na(x)) y else x

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  opt <- function(name, default = NULL) {
    i <- match(name, args)
    if (is.na(i) || i == length(args)) default else args[i + 1]
  }
  if (length(args) < 3 || is.null(opt("--collection"))) {
    cat("Usage: Rscript nets_fetch_resourcespace.R <survey_dir> --collection <id> [--list] [--refs 1,2] [--ext pdf,zip]\n")
    quit(status = 1)
  }
  nets_rs_fetch(args[1], collection = opt("--collection"),
                ext = str_split(opt("--ext", "pdf"), ",")[[1]],
                refs = if (!is.null(opt("--refs"))) str_split(opt("--refs"), ",")[[1]] else NULL,
                list_only = "--list" %in% args)
}
