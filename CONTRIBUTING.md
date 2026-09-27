# Contributing to NETS

NETS improves when the people who prepare syntheses record what they learn: how a body
wants its information, how a report series lays out its tables, what went wrong last time.

## ⛔ The one hard rule

**Never commit survey material.** No report PDFs or extracts, no StoX outputs, no values
from uncleared or unpublished results, no positions finer than whole degrees, no
screenshots or figures of results. Recipes and profiles contain code and prose; where an
example value is needed, use a synthetic one; a file that must contain synthetic positions
carries a line consisting only of the comment `# nets:allow-synthetic` (or its HTML-comment form).

Enable the pre-commit hook once per clone (from the NETS repository root). It refuses data
file types and lines with precise positions, and stamps the version:

```bash
git config core.hooksPath .githooks
```

While NETS lives inside a BAIT clone, BAIT's own hook is the active one; the NETS hook
applies once NETS is its own repository.

## What to contribute

- **Body profiles** (`nets-knowledge/bodies/`): confirmed, non-confidential facts in
  "Programme notes" (subsidiary body names, formats, languages, deadlines, lessons learned).
  Tick "Verify before use" items only when checked against the body's own documents, and
  say which document.
- **Recipes** (`cookbook/`): copy [`cookbook/_TEMPLATE.md`](cookbook/_TEMPLATE.md).
- **Scripts**: keep them local-only, quiet (counts and paths, never values), and covered by
  `tests/test_nets.R`. Run the tests before committing:
  ```bash
  Rscript tests/test_nets.R
  ```
- Keep [`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) in sync.

## Versioning

As in BAIT: the hook bumps the patch level on every commit and sets the date. Raise the
minor version by hand for new skills or a reorganised knowledge base, and the major version
for changes that break existing workspaces or manifests.

## Style

- Markdown wrapped at about 95 columns; R with tidyverse and `|>`.
- One logical change per commit or pull request; explain *why*.
