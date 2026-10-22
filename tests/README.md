# Local verification

Run `..\test.ps1` after building. It exercises the in-memory engine tests, runs a read-only audit, and renders UI tabs with those results. The UI checks verify all current/desired target fields, low-impact selection (including already configured controls), clearing selection, embedded branding, and restore-list decoding.

No Apply or Restore operation runs against Windows. Real mutation and interruption testing should use a disposable Windows VM.

Generated files in this directory are intentionally excluded from Git because they can contain machine-specific settings and identifiers. The preview executable is a test harness only; distribute dist/PrivacyDesk.exe.
