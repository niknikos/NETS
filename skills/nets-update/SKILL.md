---
name: nets-update
description: Update NETS (the EAF-Nansen survey synthesis toolkit) to the latest version — pull the repository, re-sync the nets-* skills and the nets-knowledge link, and re-run the tests. Use when the user says "update NETS" or asks for the latest body profiles or skills.
---

# Update NETS

1. Read `nets_path` from `~/.nets/config.json`. If there is no config, switch to
   [`../nets-install/SKILL.md`](../nets-install/SKILL.md).
2. Check for local changes first (the user may have edited body profiles):
   `git -C "<nets_path>" status --short`. Do not overwrite them; commit or stash with the
   user's agreement.
3. Pull: `git -C "<nets_path>" pull --ff-only`.
4. Re-sync skills (same commands as nets-install Step 6). The `nets-knowledge` symlink needs
   no action; re-copy it on Windows if it was copied rather than linked.
5. Run the tests: `Rscript "<nets_path>/tests/test_nets.R"`.
6. Tell the user what changed (`git log --oneline` since the previous head), especially
   changes to body profiles or safeguards.

Updating NETS never touches the workspace or survey material.
