# Rule #1 – PIN codes never travel over any network
- PIN codes (PIN1 and PIN2) never leave the phone when accessed via RAPP.
- RAPP must absolutely deny any attempt to transport PIN codes.
- PIN1 is cached on-device; PIN2 prompts appear only on the phone.

# Rule #2 – Zero PIN and PIN-length logging across all environments
- Never log, trace, display, or format PIN bytes, candidate PIN lengths (e.g. `\(pin.count)`), or development PIN role identifiers in log sinks, audit records, test attachments, or error strings.
- Never commit test PINs or card secrets.

- Please No AI attribution spam in commits.
  No `Co-authored-by` / `Signed-off-by` / `Reviewed-by`
  or any AI-naming trailer; subject + body only. 
- Apple uses PascalCase.
- ASCII only in source, UTF-8 only where required.
- No Magic Codes - define everything.   
- Comments describe what the code does or the constraint it honors,
  never why it changed. A past bug, a deprecation, the reasoning for a
  fix belongs in the git commit message, not the source.
- Commit often when compiles and lint is clean.
- After a feature commit, install that build on every machine that
  can run it: `Scripts/install-all-devices.sh`. The commit is the
  cheap backup; Mac, the connected iPhone or iPad, and the iPad
  simulator must match it. Do not mix the stamp `Version.xcconfig`
  rewrite into the feature commit.
- Push when feature is ready.
- Reusable agent workflows are plain scripts under `Scripts/`, each with a
  usage header, so any agent of any vendor can discover and run them. Keep
  agent guidance vendor-neutral in this AGENTS.md, not in one vendor's skill
  format.
- Verify from specifications, don't wild guess.
  `Documentation/references.md` indexes which one governs what.
  Cite what a source proves, and say what it does not.
  Where observation contradicts Apple's docs, the recorded
  exchange wins and is cited as observation, not spec.
- Never put a git worktree under `/tmp`. It is cleared on reboot and
  takes the branch's only checkout with it. Keep worktrees beside the
  repository.
- Less is more. Terse is better.
- Do not leak personal or private information in commits.
- Never store device UUIDs or UDIDs in version control; discover
  connected hardware and booted simulators dynamically at runtime.
- When stuck, research with fellow AI available.
- If something is not working, it is by default a bug in OUR code (or
  test harness), not a feature of the platform. "Impossible/blocked"
  claims require exchange-level evidence from a clean-slate repro.
- Always test and verify features with automated tests and end-to-end
  verification before handing over to the user. Never claim features work
  without automated verification.
