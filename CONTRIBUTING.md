# Contributing to ZeroCart

ZeroCart is an open-source, offline-first shopping-list app under active development. Contributions are welcome once the first release exists; until then, issues and discussion are the most useful help. By contributing you agree your contribution is licensed under the MIT License (see `LICENSE`).

## Before you start

- Open an issue first for anything beyond a small fix, so scope can be agreed. Read `docs/product-requirements.md` and `docs/decisions-and-assumptions.md`: many behaviours are deliberate (for example no permanent deletion in v1, no accounts or network).
- Out of scope for v1: accounts, sync, backend, notifications, analytics, prices, images, barcode scanning, voice input. Shared lists via a backend are planned for v2.

## Setup

1. Install the Flutter stable SDK (the version used is recorded in `README.md`), Android Studio or the Android SDK, and Xcode for iOS.
2. `flutter pub get`
3. `dart run build_runner build --delete-conflicting-outputs`
4. `tool/check.sh` should pass before you change anything.

## Making a change

- Branch from `main`. Keep changes small and focused.
- Follow the architecture in `docs/architecture.md` and the rules in `AGENTS.md` (they apply to people as well as agents).
- Add or update tests; every business rule needs a test. New or changed user-visible text goes in the ARB files for both English and Serbian.
- Run `tool/check.sh` (format, analyze, tests) before opening a pull request.
- Commit messages use Conventional Commits, for example `fix(lists): keep purchased order after reorder`.
- Update the relevant docs. If you change a business rule, say so explicitly in the pull request.

## AI-assisted contributions

AI tools are used in this project (see `docs/ai-development-workflow.md`). If you use one, you are responsible for the result: read, understand and test it, do not add dependencies you have not verified, and disclose significant AI assistance in the pull request.

## Security and repository hygiene

- Never commit secrets, signing keys, keystores or `.env` files. There are no API keys in this project.
- Report security issues privately to the maintainer instead of opening a public issue (contact details to be added when the repository is published).
- Third-party code and assets keep their own licences. Fonts are bundled under their own licences (see `README.md`); do not add assets whose licence you cannot confirm.

## Code of conduct

Be respectful and constructive. Maintainers may remove content or block users who are not.
