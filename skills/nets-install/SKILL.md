---
name: nets-install
description: 'Install or set up NETS (Nansen Evidence & Technical Synthesis), the toolkit for preparing syntheses of EAF-Nansen survey reports and StoX outputs for regional bodies (CECAF, SEAFO, SIOFA, BCC, SWIOFC). Use when the user asks to install or set up NETS, or first asks for an EAF-Nansen survey synthesis and ~/.nets/config.json does not exist. Runs the onboarding: privacy and data-agreement gate, locate the toolkit, R packages, workspace, skills, verification.'
---

# Install NETS

Goal: NETS set up **once per machine**, usable from any project, with a workspace for
confidential survey material that is outside every repository. Run the steps in order and
resolve blockers before moving on.

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

1. If `~/.nets/config.json` has a `nets_path` containing `CLAUDE.md`, `scripts/` and
   `skills/nets-install/SKILL.md`, reuse it.
2. Otherwise look for an existing clone (home, Documents, code folders). NETS may live as a
   `nets/` folder inside a BAIT clone, or as its own repository.
3. If none exists, ask where to clone. **Never** use a filesystem root or system directory
   (`/`, `C:\`, `/usr`, `C:\Program Files`); propose a folder under the user's home instead.
4. For contributors, enable the pre-commit hook from the NETS repository root:
   `git config core.hooksPath .githooks` (it blocks data files and precise positions).

## Step 3 — R packages

NETS scripts need R (≥ 4.1) with: `pdftools`, `yaml`, `jsonlite`, `dplyr`, `stringr`,
`purrr`, `readr`, `tibble`, `tidyr`, `rlang`, `knitr`. Optional: `tesseract` (OCR of scanned
pages) and Quarto (rendering syntheses to Word/HTML). Check what is missing and offer to
install it (following BAIT's `r-package-setup` skill conventions, if BAIT is installed).

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
  "installed": "<YYYY-MM-DD>" }
```

Use `"data_agreements_confirmed": false` and `"default_context_policy": "aggregates-only"`
when the user chose the second option in Step 1. Save a note to your own long-term memory
that NETS lives at `nets_path` and what it is for.

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
