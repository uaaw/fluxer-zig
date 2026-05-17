# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Known Limitations

- Gateway TLS (wss://) is not yet fully implemented. `Shard.connect()` currently uses plain TCP on port 443, which will be rejected by TLS-only endpoints. Returns `error.TLSTransportNotImplemented` with an explanatory log message on failure.

## [0.0.1] - 2026-05-17

### Added

- fix gateway resolve TLS client copy causing silent disconnect