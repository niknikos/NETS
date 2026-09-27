# Getting started: a first real test of NETS

This walks through a first, low-risk test on real material: one survey whose results are
already cleared, fetched from ResourceSpace (or copied in by hand), redacted, and turned into
a draft synthesis. Its purpose is to find out where NETS works and where it needs
adjusting, before it is used for a live submission.

## Where to run it — this matters

Run NETS **on your own computer, inside the institute's network** (office or VPN), with
Claude Code started locally (desktop app or terminal) or another local agent.

**Not in a cloud session** (Claude Code on the web / claude.ai/code). A cloud session runs
in a remote container: survey reports would be stored there rather than on your machine,
and it cannot reach ResourceSpace. NETS enforces this: its scripts stop when they detect a
cloud session. Cloud sessions remain fine for *developing* NETS with synthetic material.

## Two folders, kept apart

| Folder | What it holds | Where |
|---|---|---|
| **NETS clone** (`nets_path`) | Code, skills, knowledge — no survey material | Wherever you keep projects, e.g. `C:\Users\<you>\Documents\R projects\NETS` or `~/NETS` |
| **Workspace** (`workspace_path`) | Survey reports, extracts, evidence, drafts | Outside every git repository, e.g. `C:\Users\<you>\EAF-Nansen_NETS_workspace` |

Both paths are recorded once in `~/.nets/config.json` during installation; every command
below uses them, so NETS works wherever the clone lives. In this guide, `<nets_path>` and
`<workspace>` stand for those two folders.

## Before you start

- **Pick a test survey** whose results are already cleared or published, ideally for a
  single country, with its report in the ResourceSpace collection. You can then compare
  what NETS produces with what you know, at no risk.
- **R 4.1 or later.** Install the packages once:
  ```r
  install.packages(c("pdftools", "yaml", "jsonlite", "dplyr", "stringr", "purrr",
                     "readr", "tibble", "tidyr", "rlang", "knitr",
                     "curl", "openssl", "keyring"))
  ```
  Quarto is optional (needed only to render the synthesis to Word).
- **Model training off.** Check your agent's privacy settings before starting; the install
  step asks you to confirm it.

### On Windows

- `~/.nets/config.json` lives in your user profile, `%USERPROFILE%\.nets\config.json`
  (e.g. `C:\Users\<you>`). On managed machines the profile folder and the folder that holds
  your documents or clone can differ (for example `C:\Users\<id>` and
  `C:\Users\Administrator\Documents`). That is fine: NETS reads the clone's location from
  `nets_path`, never from `~`.
- If `Rscript` is not found, use its full path, e.g.
  `"C:\Program Files\R\R-4.x.x\bin\Rscript.exe"`.
- Where symbolic links need administrator rights, the installation copies
  `nets-knowledge/` instead of linking it; the update step then re-copies it.

## Step 1 — Install NETS

The repository is private, so git will ask you to sign in to GitHub the first time. Clone
it wherever you keep projects:

```bash
git clone https://github.com/niknikos/NETS "<nets_path>"
git -C "<nets_path>" config core.hooksPath .githooks
```

Start your agent in any folder and say: **"install NETS from `<nets_path>`"** (the actual
folder). It runs [`nets-install`](skills/nets-install/SKILL.md): the privacy and
data-agreement check, a workspace outside any repository, the skills, and the test suite,
which should end with **"All … checks passed"**.

## Step 2 — Connect ResourceSpace (you do this, not the agent)

1. Find your **private API key** on your ResourceSpace user profile. If there is none, ask
   the ResourceSpace administrators to enable API access for your account.
2. Let the agent add the address and your user name to `~/.nets/config.json` (neither is
   secret):
   ```json
   "resourcespace": { "base_url": "https://resourcespace.ad.hi.no", "user": "<user name>" }
   ```
   If the server answers only on `http`, the fetch script says so. You then choose: switch
   `base_url` to `http` (your key stays protected, but documents cross the network
   unencrypted), or download the reports yourself (Step 4).
3. **Store the key yourself** in your own R console, never in a chat:
   ```r
   keyring::key_set("nets-resourcespace", username = "<user name>")
   ```

## Step 3 — Register the survey

Say: **"Register survey <id> with NETS"**. The agent creates the survey folder and goes
through `survey.yaml` with you: areas and data owners, the body you want to test (for
example a CECAF working group), and clearance per area. For this test the areas are
`cleared`, because the results already are. If the survey has several reports, list them
under `documents` with the labels citations should use.

## Step 4 — Fetch the report

```bash
Rscript "<nets_path>/scripts/nets_fetch_resourcespace.R" "<workspace>/<survey_id>" --collection 124 --list
Rscript "<nets_path>/scripts/nets_fetch_resourcespace.R" "<workspace>/<survey_id>" --collection 124 --refs <ref>
```

The listing shows what the collection holds; download only the report(s) for this survey.
This is the first real test of the connection. If the listing works but downloads fail,
the server probably restricts direct file access for API users.

**Or copy the PDFs yourself** into `<workspace>/<survey_id>/sources/reports/`. The agent
never opens that folder.

## Step 5 — Extract, redact, and check it yourself

```bash
Rscript "<nets_path>/scripts/nets_ingest_pdf.R" "<workspace>/<survey_id>"
```

Open `context/<report>.md` and `context/<report>.index.md` yourself, with the original PDF
beside them, and note:

- Is every position finer than whole degrees shown as `[COORD]`? Watch the notations this
  report series uses.
- Were the station annexes withheld, and were any ordinary pages withheld by mistake?
- Are the biomass tables readable, or did extraction scramble columns?
- Were pages flagged as having no text (scanned)? Try again with `--ocr` if so.

## Step 6 — Draft a synthesis

Say: **"Prepare a synthesis of survey <id> for <body>"**. The agent builds the evidence
log, asks you to verify each entry against the PDF, drafts the `.qmd` and runs the release
check. Compare the result with what was actually submitted for that survey, if anything was.

To combine **several surveys** (e.g. a time series), say **"Prepare a synthesis of surveys
<id>, <id> for <body>"**; the agent creates a synthesis project
(`<workspace>/_syntheses/<name>/`) in which each survey keeps its own clearance and
verified evidence.

## Step 7 — Report what you found

Improvements to NETS can be made in any session, including a cloud session, because they
need only descriptions, never survey content. **Describe problems in words**, for example:
"positions written as `DD MM.m N` (no degree sign) were not masked", or "pages 12–14
were withheld wrongly". Do not paste report text, values or real positions. Each problem
then becomes a fix and a test in NETS.
