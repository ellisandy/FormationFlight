# Contributing to Formation Flight

Thanks for your interest. Formation Flight is a small, single-maintainer project, so this guide is short.

## Reporting bugs and suggesting features

Open an [issue](https://github.com/ellisandy/FormationFlight/issues/new/choose) using the bug report or feature request template. For bugs, the most useful details are:

- Device model and iOS version
- App version (from the App Store page, or Settings ▸ Apps ▸ Formation Flight on iOS)
- What you did, what you expected, and what happened instead
- For readout problems: the mission type (TOT or hack), roughly how far from the target you were, and whether you were turning

## Pull requests

Small, focused pull requests are welcome: bug fixes, test improvements, accessibility fixes, and documentation. **For new features or anything that changes how the instruments are computed, please open an issue first** so we can agree on the approach before you spend time on it. Navigation behaviour is safety-adjacent, and changes to it are made deliberately (see [`docs/decisions/`](docs/decisions/)).

### Setup

See [Getting started](README.md#getting-started) in the README. There are no dependencies to install.

### Guidelines

- **Branch** from `main` and keep each PR to one change.
- **Match the surrounding code.** Swift 6, SwiftUI, a view + view-model per feature, `async`/`await` rather than Combine. Use Xcode's default formatting (4-space indentation).
- **Add or update tests.** Unit tests use [Swift Testing](https://developer.apple.com/documentation/testing) (`@Test`, `#expect`) and live in `Formation FlightTests/`, mirroring the app's folder layout. UI tests use XCUIAutomation.
- **Run the full test plan** (⌘U) before opening the PR.
- **Localize user-facing strings** through `Shared Assets/Localizable.xcstrings`.
- **Don't commit signing changes** (team or bundle identifier) or files under `xcuserdata/`.
- **Write a clear PR description:** what changed, why, and how you tested it. Screenshots help for UI changes.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
