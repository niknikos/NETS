---
name: nets-install
description: 'Install or set up NETS (Nansen Evidence & Technical Synthesis), the toolkit for preparing syntheses of EAF-Nansen survey reports and StoX outputs for regional bodies (CECAF, SEAFO, SIOFA, BCC, SWIOFC). Use when the user asks to install or set up NETS, or first asks for an EAF-Nansen survey synthesis and ~/.nets/config.json does not exist. Runs the onboarding: privacy and data-agreement gate, locate the toolkit, R packages, workspace, skills, verification.'
---

# Install NETS

Goal: NETS set up **once per machine**, usable from any project, with a workspace for
confidential survey material that is outside every repository. Run the steps in order and
resolve blockers before moving on.

## Step 0 — Check where you are running

NETS handles real survey material only on the user's own computer, inside the institute's
network. If `CLAUDE_CODE_REMOTE` is set, this is a cloud session: stop the installation,
explain that reports would be stored in a remote container and that ResourceSpace is not
reachable from it, and point to [`GETTING-STARTED.md`](../../GETTING-STARTED.md). Working on
NETS's own code and tests with synthetic material is fine in a cloud session.

## Step 1 — Privacy and data-agreement gate (blocking, once)

Survey reports contain partner countries' unpublished results. Unlike a database query,
synthesising a report means **its text is sent to the model provider for processing**.
Two conditions must hold before that is acceptable:

1. **Model training and data retention are off** for the agent in use. If
   `~/.bait/config.json` already records `privacy_onboarded_at` for this agent, tell the user
   and ask only for a short confirmation that it still holds. Otherwise follow the
   provider-specific guidance in BAIT's `biotic-privacy` skill, or point the user to their
   provider's current privacy / data-controls page (menus change; do not assert a path).
   Prefer API, team or enterprise tiers with zero data retention.
2. **The user's agreements permit it.** Ask the user to confirm that the programme's data
   policy and their institution's rules allow unpublished survey report text to be processed
   by this provider under these settings. If they are unsure, recommend setting
   `context_policy: aggregates-only` or `local-only` in each survey until it is clarified
   (see [`../../nets-knowledge/data-governance.md`](../../nets-knowledge/data-governance.md)).

Gate on an explicit choice (a selection prompt in Claude Code): **"Training is off and my
data agreements allow this processing"**, **"Training is off, but agreements are unclear —
use aggregates-only by default"**, or **"Stop"**. Record the answer in Step 5.

## Step 2 — Locate the NETS toolkit

1. If the user names a folder ("install NETS from <folder>"), use it. Otherwise, if
   `~/.nets/config.json` has a `nets_path` containing `CLAUDE.md`, `scripts/` and
   `skills/nets-install/SKILL.md`, reuse it.
2. Otherwise look for an existing clone: the current working directory, home, Documents
   (including `Documents\R projects` and similar), code folders. On Windows the profile
   folder (`%USERPROFILE%`, where `~/.nets/` lives) and the folder holding the user's
   documents or clone can differ (e.g. `C:\Users\<id>` and `C:\Users\Administrator\Documents`);
   never assume the clone is under `~`. Early versions lived in a `nets/` folder inside a
   BAIT clone; if you find one, suggest switching to the standalone repository
   (https://github.com/niknikos/NETS) and update `nets_path`.
3. If none exists, ask where to clone
   (`git clone https://github.com/niknikos/NETS "<path>"`; the repository may be private,
   so the user needs access). **Never** use a filesystem root or system directory
   (`/`, `C:\`, `/usr`, `C:\Program Files`); propose a folder under the user's home instead.
4. For contributors, enable the pre-commit hook from the NETS repository root:
   `git config core.hooksPath .githooks` (it blocks data files and precise positions).

## Step 3 — R packages

NETS scripts need R (≥ 4.1) with: `pdftools`, `yaml`, `jsonlite`, `dplyr`, `stringr`,
`purrr`, `readr`, `tibble`, `tidyr`, `rlang`, `knitr`. Optional: `tesseract` (OCR of scanned
pages), Quarto (rendering syntheses to Word/HTML), and `curl`, `openssl`, `keyring` (fetching
reports from ResourceSpace). Check what is missing and offer to
install it (following BAIT's `r-package-setup` skill conventions, if BAIT is installed).

If `Rscript` is not on the PATH (common on Windows), use its full path
(`C:\Program Files\R\R-<version>\bin\Rscript.exe`) in every command and tell the user.

## Step 4 — Workspace for survey material

Ask where to keep survey material. Suggest `~/EAF-Nansen_NETS_workspace/`
(`%USERPROFILE%\EAF-Nansen_NETS_workspace\` on Windows), or the institution's approved secure
storage if one is required.

- It must be **outside any git repository** (the scripts refuse otherwise).
- Avoid cloud-synced folders unless the user's agreements allow survey data there.
- Never at a filesystem root or system directory.

## Step 5 — Record the configuration

Write or merge `~/.nets/config.json`:

```json
{ "nets_path": "<path to the NETS folder>",
  "workspace_path": "<workspace>",
  "privacy_onboarded_at": "<YYYY-MM-DD>",
  "privacy_onboarded_for": "<agent and tier>",
  "data_agreements_confirmed": true,
  "default_context_policy": "standard",
  "skills_synced_to": ["~/.claude/skills", "~/.codex/skills"],
  "knowledge_copied": false,
  "installed": "<YYYY-MM-DD>" }
```

Set `"knowledge_copied": true` when Step 6 had to copy `nets-knowledge/` instead of linking
it; updates then re-copy it. On Windows, write this file with the agent's file tool: some
managed machines run PowerShell in constrained language mode, where .NET calls such as
`New-Object` fail.

Use `"data_agreements_confirmed": false` and `"default_context_policy": "aggregates-only"`
when the user chose the second option in Step 1. Save a note to your own long-term memory
that NETS lives at `nets_path` and what it is for.

## Step 5b — ResourceSpace connection (optional)

If the user's reports are in a ResourceSpace archive (e.g. IMR's), NETS can fetch whole
collections into a survey's `sources/` folder. This runs on the user's machine, inside the
institute's network.

1. Add the address and user name (not secret) to `~/.nets/config.json`:
   ```json
   "resourcespace": { "base_url": "https://<host>", "user": "<ResourceSpace user name>" }
   ```
   Prefer `https`. If only `http` works, the script warns: the signed query protects the key,
   but documents cross the network unencrypted.
2. The API needs the user's **private API key** (from their ResourceSpace user profile;
   administrators may need to enable API access). **The user stores it themselves**, in
   their own R console, never in chat, the config file or a repository:
   ```r
   keyring::key_set("nets-resourcespace", username = "<ResourceSpace user name>")
   ```
   It is kept in the operating system's credential store (Keychain, Windows Credential
   Manager, Secret Service). For non-interactive use, `NETS_RS_KEY` in the environment also
   works, but is less protected.
3. Test with a listing: `Rscript "<nets_path>/scripts/nets_fetch_resourcespace.R"
   "<any survey_dir>" --collection <id> --list`.

If the user offers to type a password or key into the chat, decline and explain why.

## Step 6 — Install skills globally and link the knowledge

NETS skills refer to `../../nets-knowledge/`, a name chosen so it cannot collide with
BAIT's `knowledge/`.

- macOS/Linux:
  ```bash
  mkdir -p ~/.claude/skills ~/.codex/skills
  cp -R "<nets_path>/skills/." ~/.claude/skills/
  cp -R "<nets_path>/skills/." ~/.codex/skills/
  ln -sfn "<nets_path>/nets-knowledge" ~/.claude/nets-knowledge
  ln -sfn "<nets_path>/nets-knowledge" ~/.codex/nets-knowledge
  ```
- Windows (PowerShell; symlinks need Developer Mode or admin, otherwise copy and re-copy on
  every update):
  ```powershell
  New-Item -ItemType Directory -Force "$HOME/.claude/skills", "$HOME/.codex/skills" | Out-Null
  Copy-Item -Recurse -Force "<nets_path>/skills/*" "$HOME/.claude/skills/"
  Copy-Item -Recurse -Force "<nets_path>/skills/*" "$HOME/.codex/skills/"
  New-Item -ItemType SymbolicLink -Force -Path "$HOME/.claude/nets-knowledge" -Target "<nets_path>/nets-knowledge"
  New-Item -ItemType SymbolicLink -Force -Path "$HOME/.codex/nets-knowledge" -Target "<nets_path>/nets-knowledge"
  ```
  If creating the link fails ("Administrator privilege required"), copy instead and record
  `"knowledge_copied": true` in the configuration:
  ```powershell
  Copy-Item -Recurse -Force "<nets_path>/nets-knowledge" "$HOME/.claude/nets-knowledge"
  ```

Sync only to agents the user has installed.

## Step 7 — Verify

```bash
Rscript "<nets_path>/tests/test_nets.R"
```

The tests use synthetic material only. All checks should pass; if not, fix the cause
(usually a missing package) before continuing.

## Done

Summarise: where NETS and the workspace are, the recorded privacy/agreement status and
default context policy, and the next step — *"create a survey with nets-ingest"*.
Updates are handled by [`../nets-update/SKILL.md`](../nets-update/SKILL.md).
