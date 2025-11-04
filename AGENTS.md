# Repository Guidelines

## Project Structure & Module Organization
- Core SwiftUI app sources live in `Sources/UnclutterPlus`, grouped by feature managers (Clipboard, Notes, Preferences) and SwiftUI views; keep new files co-located with their feature peer.
- Localized resources and the app icon reside under `Sources/UnclutterPlus/Resources`; add new `.lproj` assets there and register them in `Package.swift`.
- Shared developer docs (release flow, security) are in `docs`, while automation lives in `scripts`; tests belong in `Tests/UnclutterPlusTests` alongside new `XCTestCase` suites.

## Build, Test, and Development Commands
- `swift build` creates a debug build; append `-c release` for optimized binaries.
- `./scripts/build.sh` wraps the release build and bundles assets; use it before distributing artifacts.
- `swift test` runs the XCTest suite; combine with `--filter Module/ClassName` to target a subset.
- `./start.sh` launches the debug binary from `.build/debug`; pair with `./stop.sh` to terminate the helper process.
- `open Package.swift` opens the project in Xcode for GUI-driven debugging.

## Coding Style & Naming Conventions
- Follow Swift 5.9 defaults: four-space indentation, trailing commas on multi-line literals, and `PascalCase` types with `camelCase` members.
- Prefer SwiftUI previews for UI work; colocate previews with their view structs.
- Use guard statements for early exits and keep state management inside dedicated manager classes (e.g., `ClipboardManager`).
- Let Xcode's reformat (`⌃I`) or `swift-format` (if installed) tidy files before pushing.

## Testing Guidelines
- Extend `Tests/UnclutterPlusTests` with focused XCTest files named `<Feature>Tests.swift`; mirror the production namespace.
- Cover UI-less logic (managers, utilities) with deterministic unit tests and assert side effects like file writes via temporary directories.
- Run `swift test` locally before each PR; aim to cover new branches and add regression tests when fixing bugs.

## Commit & Pull Request Guidelines
- Follow the Conventional Commits style seen in history (`fix:`, `feat:`, `perf:`); keep subjects under 72 characters and write descriptive bodies when rationale matters.
- Rebase on `main` before opening a PR, summarize changes, link Issues, and attach screenshots or screen recordings for UI-facing tweaks.
- Ensure CI scripts pass locally (`swift build`, `swift test`) and update README or docs when behavior or workflows change.

## Security & Configuration Tips
- Review `SECURITY.md` before shipping features touching sensitive clipboard or file data; never log raw clipboard content.
- Store machine-specific overrides in user defaults or ignored plist files, not in version control.
