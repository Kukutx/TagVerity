# Security and scope

## Allowed scope

TagVerity only performs:

- NFC availability checks;
- ISO 14443, ISO 15693 / NFC-V, and ISO 18092 / NFC-F tag discovery within the configured platform scope;
- public tag identifiers and technology metadata exposed by Android/iOS;
- read-only standard NDEF parsing;
- local scan history, batch inspection, privacy scrubbing, and explicit exports.

## Explicitly excluded

TagVerity does not implement:

- card emulation, HCE, Secure Element credentials, or Wallet credentials;
- UID spoofing, cloning, relay, or replay;
- MIFARE key recovery, authentication attempts, or dictionary attacks;
- arbitrary APDU/transceive consoles;
- protected page/block reads;
- tag writing, formatting, locking, or destructive operations;
- attempts to bypass access-control, ticketing, payment, or production systems.

## Privacy

- Current scans may display a raw UID when the OS exposes it.
- History stores a SHA-256 fingerprint by default, not the raw UID.
- Raw UID history is opt-in.
- NDEF history is opt-in.
- Selected linkable technical identifiers are removed from history by default.
- Diagnostics are memory-only and redact identifier-like values.
- No network, analytics, ads, telemetry, or background upload is implemented.

Stable SHA-256 fingerprints are pseudonymous, not anonymous, and can correlate the same exposed UID over time. Session-only fingerprints are marked as such and are not used for repeated-ID comparison.

## Reporting security issues

Do not include real sensitive tag payloads, access credentials, signing material, or proprietary card secrets in public bug reports. Use GitHub Private Vulnerability Reporting for security-sensitive issues and redacted diagnostics whenever possible.
