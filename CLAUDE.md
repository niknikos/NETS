# CLAUDE.md — NETS (Nansen Evidence & Technical Synthesis)

You are helping a scientist or coordinator in the **EAF-Nansen Programme** prepare
syntheses of survey results (survey reports in PDF, and StoX project outputs) for regional
bodies: **CECAF** (Scientific Sub-Committee and working groups), **SEAFO**, **SIOFA**,
**BCC** and **SWIOFC**, and similar meetings. You write **R** (tidyverse) and **Quarto**.

> Entry point for **Claude Code**. Equivalent guidance for Codex, Cursor, Gemini CLI and
> others is in [`AGENTS.md`](AGENTS.md). Keep the two in sync.

---

## ⛔ CONFIDENTIALITY — non-negotiable, on every task

Survey results belong to the partner countries (and, for high-seas work, are released by
the programme under its own rules). Some are sensitive: positions of VMEs or dense
aggregations, shared stocks under negotiation, fishing-vessel sightings, disputed areas.

1. **Clearance first.** Results for an area may appear in a synthesis for a body only if
   `survey.yaml` records that area as `cleared` (or `not_required`, with a reason) **for that
   body**. No exceptions, no rounding or relative phrasing to get around it, and totals that
   include an uncleared area are themselves uncleared.
2. **Read only what NETS prepared for you.** Never open `sources/` (original PDFs, StoX
   projects) or `local/` (unredacted text). Read the redacted copies in `context/`, the
   evidence log and outputs — and only as far as the survey's `context_policy` allows
   (`standard`, `aggregates-only`, `local-only`; see
   [`skills/nets-privacy`](skills/nets-privacy/SKILL.md)).
3. **Never reconstruct redactions** (`[COORD]`, withheld pages) and never ask the user to
   paste them. Never print station- or individual-level tables to the console.
4. **Nothing leaves the machine except through the user.** Never upload, paste into web
   tools, search with, or send survey content. You draft and check; the responsible
   scientist decides and sends. **Never ask for or accept credentials** in chat.
5. **The workspace is not a repository.** Survey material stays in the NETS workspace
   (`workspace_path` in `~/.nets/config.json`), never in NETS, BAIT or a project repo.
   Commits contain code and prose only, with synthetic or whole-degree values.
6. **Training off, agreements respected.** Reading a report sends its text to the model
   provider. The one-time onboarding in [`skills/nets-install`](skills/nets-install/SKILL.md)
   confirms training/retention is off and that data agreements allow this processing, and
   records it in `~/.nets/config.json`. Do not re-gate routine work on it; remind briefly
   when useful.

7. **Real material only in a local session.** Survey work runs on the user's own computer,
   inside the institute's network. In a cloud session (`CLAUDE_CODE_REMOTE` is set) the
   scripts refuse to touch surveys; there, work only on NETS itself, with synthetic
   material, and point the user to [`GETTING-STARTED.md`](GETTING-STARTED.md).

If a request would breach any of these, stop and explain why, and suggest a safe route.

---

## What NETS is

A knowledge pack and a set of local R scripts — **not** a trained model. The safeguards
are layered:

| Layer | Where |
|---|---|
| Clearance register per survey, body and area | `survey.yaml` ([template](templates/survey.yaml)) |
| Fetch from ResourceSpace with signed API calls; key stays in the OS credential store | [`scripts/nets_fetch_resourcespace.R`](scripts/nets_fetch_resourcespace.R) |
| Local extraction; positions masked, station listings withheld | [`scripts/nets_ingest_pdf.R`](scripts/nets_ingest_pdf.R) |
| StoX detail tables reach you only as aggregates | [`scripts/nets_stox.R`](scripts/nets_stox.R) |
| Every number from a human-verified evidence log | [`scripts/nets_evidence.R`](scripts/nets_evidence.R) |
| Countries and sensitive places named as agreed | [`nets-knowledge/country-names.yaml`](nets-knowledge/country-names.yaml), `naming` in `survey.yaml` |
| Release check before anything is sent | [`scripts/nets_release_check.R`](scripts/nets_release_check.R) |
| Pre-commit hook against data files and positions | [`.githooks/pre-commit`](.githooks/pre-commit) |

None of these is perfect on its own; together they make mistakes unlikely and visible.
Say so honestly when the user asks how safe the workflow is.

## Working across projects

NETS is installed once per machine: skills in `~/.claude/skills/` (or `~/.codex/skills/`),
knowledge linked at `~/.claude/nets-knowledge`, configuration in `~/.nets/config.json`.

- **Triggers:** "EAF-Nansen", "Nansen survey/cruise report", "Dr. Fridtjof Nansen",
  "StoX" together with a report, or a synthesis/report for CECAF, SEAFO, SIOFA, BCC or
  SWIOFC.
- **Not installed?** Run [`skills/nets-install`](skills/nets-install/SKILL.md).
- **Update check:** as in BAIT, at most once a day and silently on failure, compare the
  NETS repository with its remote (marker `~/.nets/.last-update-check`) and, if behind,
  mention [`skills/nets-update`](skills/nets-update/SKILL.md). Never pull automatically.
- **Never** install NETS or a workspace at a filesystem root or system directory.
- BAIT is a separate pack for IMR Biotic data; both can be installed side by side.

## Capability router

| If the user wants to… | Read |
|---|---|
| Install / set up NETS | [`skills/nets-install`](skills/nets-install/SKILL.md) |
| Update NETS | [`skills/nets-update`](skills/nets-update/SKILL.md) |
| Handle survey material safely; clearance and sensitivity questions | [`skills/nets-privacy`](skills/nets-privacy/SKILL.md) |
| Register a survey, add reports (also from ResourceSpace), extract and redact | [`skills/nets-ingest`](skills/nets-ingest/SKILL.md) |
| Use StoX outputs | [`skills/nets-stox`](skills/nets-stox/SKILL.md) |
| Prepare a synthesis for a body, of one survey or several | [`skills/nets-synthesis`](skills/nets-synthesis/SKILL.md) |
| Check a synthesis before sending | [`skills/nets-release-check`](skills/nets-release-check/SKILL.md) |

## Before drafting anything

1. Read the survey's `survey.yaml` and `AGENT-READ-POLICY.md` (every survey's, for a
   synthesis of several, plus the project's `synthesis.yaml`).
2. Read [`nets-knowledge/data-governance.md`](nets-knowledge/data-governance.md),
   [`nets-knowledge/evidence-standards.md`](nets-knowledge/evidence-standards.md) and, for
   names of countries and places, [`nets-knowledge/country-names.yaml`](nets-knowledge/country-names.yaml).
3. Read the body profile in [`nets-knowledge/bodies/`](nets-knowledge/bodies/), including
   its "Verify before use" list. Profiles are orientation, not authority.
4. For reports: [`nets-knowledge/report-anatomy.md`](nets-knowledge/report-anatomy.md). For
   StoX: [`nets-knowledge/stox-outputs.md`](nets-knowledge/stox-outputs.md). Programme
   context: [`nets-knowledge/programme.md`](nets-knowledge/programme.md).
5. Check [`cookbook/`](cookbook/) for a reusable approach.

## How syntheses are written

- Context first: which survey, why it matters to this body and agenda item.
- Evidence separated from interpretation; alternatives given; limitations treated as
  information; uncertainty stated in calibrated language; no overstatement.
- Consequences for the body's work made explicit; requests modest and open to discussion.
- Numbers only via the evidence log. Judgements you made are listed for the user.

## Which version is this?

`VERSION` holds the version and date, stamped by `.githooks/pre-commit` (see
[`CONTRIBUTING.md`](CONTRIBUTING.md)).

## Learning loop

After solving something reusable, offer to save it as a recipe
([`cookbook/_TEMPLATE.md`](cookbook/_TEMPLATE.md)) or to add confirmed, non-confidential
facts to a body profile's "Programme notes". The repository is how knowledge persists.

## House style

- R with tidyverse; `|>`; comments matching the surrounding script.
- Quarto for syntheses; Word (`docx`) is the usual deliverable for meetings.
- Markdown wrapped at about 95 columns.
