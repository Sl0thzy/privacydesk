# Working on PrivacyDesk

This repository is the canonical project. Make all source edits, builds, and packaging here. Do not edit the earlier Desktop copy.

Build: `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1`.
Test: `powershell -NoProfile -ExecutionPolicy Bypass -File .\test.ps1`.

Never apply privacy changes to the developer's PC as part of a test. Use the engine's in-memory SelfTest mode, read-only Audit, and the preview UI harness. Real Apply/Restore tests require a disposable VM or explicit authorization.

Keep local audit output, logs, snapshots and machine/user identifiers out of Git. The tests directory is ignored except its README. Preserve the automatic snapshot-before-write journal and per-value restoration semantics.

Ship `dist/PrivacyDesk.exe`, README, checksum and the portable ZIP. Regenerate the icon from the original logo using make-icon.ps1 (invoked by build.ps1). The update button opens https://github.com/Sl0thzy/privacydesk only when clicked.
