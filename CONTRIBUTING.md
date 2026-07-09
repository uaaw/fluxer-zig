# Contributing

Thank you for your interest in contributing to **fluxer**!

## Getting Started

1. Clone the repository.
2. Ensure you have Zig 0.13 or later installed.
3. Run `zig build test` to verify your environment.

## Development Guidelines

See [DEVELOP.md](DEVELOP.md) for detailed development conventions.

- `//` comments may be written in Japanese.
- Public API doc comments (`///`) must be written in English.
- When changing APIs, update both [API_DESIGN.md](API_DESIGN.md) and [ARCHITECTURE.md](ARCHITECTURE.md).

## Code Style

- Project language is English.
- Use `//` for comments.
- Keep comments to a minimum.

## Submitting Changes

1. Fork the repository.
2. Create a new branch for your feature or fix.
3. Run `zig build test` and ensure all tests pass. This is mandatory.
4. Submit a pull request with a clear description.
