# 🕸️ NETS — Nansen Evidence & Technical Synthesis

<!-- version -->**Version 0.2.9** (2026-09-27)<!-- /version -->

**Help your AI coding agent turn EAF-Nansen survey reports and StoX outputs into careful,
traceable syntheses for regional bodies — without losing control of partners' data.**

The EAF-Nansen Programme reports survey execution and results to several bodies: the
CECAF Scientific Sub-Committee and its working groups, SEAFO, SIOFA, the Benguela Current
Commission (BCC) and SWIOFC. Each needs different things from the same survey, and each
submission must respect what every partner country has agreed to share. NETS gives a
general coding agent (Claude Code, Codex, Cursor, …) the procedures, background and local
tools to prepare those syntheses well, and makes the safeguards part of the workflow rather
than an afterthought.

NETS is a sibling of [BAIT](https://github.com/DeepWaterIMR/BAIT), the IMR Biotic AI Toolkit, and follows the same
design: a knowledge pack the agent reads at runtime, not a trained model.

## What it does

1. **Registers a survey** in a local workspace, with a manifest (`survey.yaml`) recording
   areas, data owners, and **clearance per area for each body**. Reports can be fetched from
   a ResourceSpace archive (e.g. IMR's) with signed API calls; the key stays in the
   operating system's credential store.
2. **Extracts report PDFs locally**, masks positions with sub-degree precision and withholds
   station-listing pages before the agent reads anything. French, Portuguese and English
   notations are handled; scanned pages can be OCR'd.
3. **Inventories StoX outputs** (2.7 and 3.x) without reading values, and passes only
   aggregates (stratum, area, species, length group) to the agent.
4. **Builds an evidence log**: every number in a synthesis is drawn from a logged entry with
   its source page and table, marked reported or derived, and checked by a person.
5. **Drafts the synthesis** in Quarto with evidence and interpretation kept apart,
   uncertainty and comparability stated, and a clearance statement generated from the
   manifest — as a document (Word, HTML) or a slide deck (HTML reveal.js, PowerPoint). HTML
   is self-contained and also renders where group policy blocks Quarto's HTML step.
6. **Combines several surveys** when needed (a time series, neighbouring surveys) in a
   synthesis project: each survey keeps its own clearance and verified evidence, and a value
   calculated across surveys counts as cleared only if everything it uses is.
7. **Runs a release check** on the source and every rendered file: precise positions,
   uncleared or sensitive evidence, unverified values, country names in forms to avoid,
   sensitive place names not agreed with the data owners, typed-in numbers and draft
   markings.

## 🔒 How the safeguards work — and their limits

BAIT can promise that raw data never leaves the machine, because the agent only sees query
aggregates. A synthesis tool cannot make quite the same promise: to synthesise a report,
the agent has to read its text, and that text is processed by the model provider. NETS
therefore relies on these layers:

| Safeguard | What it does | Limit |
|---|---|---|
| One-time onboarding | Training/retention off; user confirms data agreements allow this processing | Relies on the user's confirmation |
| Context policy per survey | `standard`, `aggregates-only`, or `local-only` (no cloud model at all) | The agent follows it; scripts enforce it where they can |
| Local redaction | Masks positions, withholds station listings, keeps full text in `local/` | Pattern-based: unusual notations can slip through; the user reviews the log |
| Clearance register | Results only for areas cleared for that body | Only as current as `survey.yaml` |
| Evidence log | Numbers traced to page and table, verified by a person | Verification is a human task |
| Country register | Names countries as agreed; sensitive place names need recorded agreement | Written from general knowledge; programme staff confirm |
| Release check | Fails on positions, uncleared or sensitive evidence, names to avoid | Cannot judge figures or indirect disclosure |
| Pre-commit hook | Blocks data files and positions in commits | Can be bypassed with `--no-verify` |

Where survey agreements do not allow processing by a cloud provider at all, set
`context_policy: local-only`; NETS will then support the workflow but refuse to draft from
survey content. A local model is the appropriate route in that case.

## 🚀 Quickstart

For a first test on real material, follow [`GETTING-STARTED.md`](GETTING-STARTED.md). Run
NETS on your own computer inside the institute's network, not in a cloud agent session: the
scripts refuse to handle survey material in a cloud session.

1. Have R (≥ 4.1) and an agent. Tell the agent:
   ```
   install NETS from https://github.com/niknikos/NETS
   ```
   It runs [`nets-install`](skills/nets-install/SKILL.md): onboarding, R packages, a
   workspace outside every repository, global skills, and the test suite.
2. *"Register survey 2026406 and ingest its report"* →
   [`nets-ingest`](skills/nets-ingest/SKILL.md).
3. *"Prepare a synthesis of this survey for the CECAF small pelagics working group"* →
   [`nets-synthesis`](skills/nets-synthesis/SKILL.md), which ends with
   [`nets-release-check`](skills/nets-release-check/SKILL.md). You decide what is sent.

## 🗂️ What's inside

| Path | Contents |
|---|---|
| [`GETTING-STARTED.md`](GETTING-STARTED.md) | Step-by-step first real test |
| [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) | Agent entry points: confidentiality rules and router |
| [`skills/`](skills/) | Procedures: install, update, privacy, ingest, StoX, synthesis, release check |
| [`nets-knowledge/`](nets-knowledge/) | Data governance, evidence standards, report anatomy, StoX, programme context, country-name register, one profile per body |
| [`scripts/`](scripts/) | Local R tools (extraction and redaction, StoX, evidence log, synthesis projects, drafting, rendering, release check) |
| [`templates/`](templates/) | `survey.yaml` and `synthesis.yaml` manifests; Quarto templates for the synthesis and the slide deck |
| [`tests/`](tests/) | End-to-end tests on synthetic material generated at run time |
| [`cookbook/`](cookbook/) | Reusable recipes (grows with use) |

The workspace for one survey looks like this (outside every repository):

```
<workspace>/<survey_id>/
  survey.yaml            ownership, clearance, sensitivity   (agent reads first)
  AGENT-READ-POLICY.md   what the agent may read
  sources/               original PDFs and StoX projects     (agent never reads)
  local/                 unredacted extracted text           (agent never reads)
  context/               redacted text, indexes, StoX inventory and summaries
  evidence/              evidence-log.csv
  outputs/<BODY>/        synthesis drafts, slide decks and release checks

<workspace>/_syntheses/<name>/      (only for a synthesis of several surveys)
  synthesis.yaml         body, meeting, member surveys
  evidence/              derived-log.csv (values calculated across surveys)
  outputs/<BODY>/        drafts and release checks
```

## ⚠️ Please review before relying on it

- **Body profiles** in `nets-knowledge/bodies/` were written from general knowledge. Each has
  a "Verify before use" list and a "Programme notes" section for programme staff to confirm
  subsidiary bodies, formats, languages and deadlines.
- **StoX layouts** vary by version and project; NETS discovers tables rather than assuming
  names, but confirm with project owners which output holds the published estimate.
- **Redaction** reduces risk; it does not replace reading the redaction log.
- **The country register** (`nets-knowledge/country-names.yaml`) was written from general
  knowledge of UN and FAO usage. Programme staff should confirm the names (especially French
  and Portuguese), the forms to avoid and the list of sensitive places.

## 🧠 It learns from you

Reusable approaches go in [`cookbook/`](cookbook/); confirmed facts about each body go in
its profile. See [`CONTRIBUTING.md`](CONTRIBUTING.md).
