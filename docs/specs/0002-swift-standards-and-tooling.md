# 0002. Enforce Swift style with swift-format, a check script, and a git hook

**Date**: 2026-10-28
**Status**: Proposed

## Summary

Screencopy will use Apple's own `swift-format` (already inside your Xcode) to format and lint every Swift file, so there is one style and nothing new to install. One script, `scripts/check`, runs the checks by hand, and a small git hook runs them on the files you are about to commit. Force unwraps, `try!`, and implicitly unwrapped optionals are banned in app and package code. Existing code is formatted once in its own commit, and from then on new code has to comply.

## Context

The scaffold from spec 0001 exists: an Xcode app target and a local Swift package, 28 Swift files, 4 space indentation, a few lines up to 175 characters. There is no formatter, no linter, no `AGENTS.md`, and the folder is not yet a git repository, so nothing stops style drift and a pre commit check has nowhere to live.

Forces:
- One developer, one Mac, a personal tool. Every extra tool is one more thing to keep working against new Swift releases (this machine runs Swift 6.4 and Xcode 27.1).
- Spec 0001 chose Swift 6 strict concurrency to catch races at compile time. Warnings that scroll past in Xcode weaken that.
- The app captures screen content. A crash from a force unwrap loses the capture, so avoidable crash sites are worth banning.
- Checks that take more than a second or two get skipped. Slow checks protect nothing.

## Options considered

### Option 1: Apple swift-format, one tool for format and lint

Ships in the Xcode toolchain (`xcrun swift-format`), one JSON config, one binary for both jobs.

**Pros**:
- Nothing to install, nothing to version pin. Follows Swift releases because it is built from the same source tree as the compiler.
- A single config file.

**Cons**:
- Fewer lint rules than SwiftLint. No unused import or complexity checks.
- Fewer formatting options than SwiftFormat.

### Option 2: SwiftLint plus a formatter

Brew installed. Many more rules and an optional Xcode build phase.

**Pros**:
- Catches more (complexity, unused code, many opinionated rules).

**Cons**:
- Second tool, second config, and a Homebrew dependency to keep working. More rules than a one person app has a use for.

### Option 3: No tooling, rely on Xcode

**Pros**: Zero setup.

**Cons**: Style drifts. Nothing enforces the banned patterns.

## Decision

**Chosen option**: Option 1: Apple swift-format for format and lint.

Format and lint with `xcrun swift-format` using one repo config, run by `scripts/check` and a plain git hook, with warnings treated as errors in the check script only.

**Implementation skills**: `swiftui-expert-skill` (`avdlee/swiftui-agent-skill`, `.agents/skills/swiftui-expert-skill/`). It governs SwiftUI code, not formatting, so it does not change this decision. No new Agent Skills or MCP servers were chosen here; the offer was declined.

## Rationale

The scope's "Done when" for this feature is that lint and format run clean on the real project. `swift-format` meets that with zero new installs, and I verified it against this machine: under the chosen config the existing code has only 2 violations (one line over 120 columns, one force unwrap in the permission message URL). A heavier linter would add upkeep without a problem it solves today.

Hook scope is kept to formatting and linting staged files so it stays fast. Tests run separately (`swift test`, and `/check verify`), so a slow suite never tempts you to bypass the hook.

Warnings fail only in `scripts/check`, because Xcode must stay forgiving while a change is half written, and a deprecation warning after an Apple update should not block a build you need to run.

You declined the extra checks for `print` and for network imports, and doc comments on public API. Those stay unenforced. Spec 0001's "no network" and "nothing logged" rules remain checked by `/check verify` only.

## Standard definition

**Canonical pattern**:

`.swift-format` at the repo root:

```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": { "spaces": 4 },
  "rules": {
    "NeverForceUnwrap": true,
    "NeverUseForceTry": true,
    "NeverUseImplicitlyUnwrappedOptionals": true
  }
}
```

`ScreencopyKit/Tests/.swift-format` repeats the same config with the three `Never...` rules set to `false`, so tests may force unwrap. (swift-format picks the nearest config above a file; confirm this at install, see Follow-up.)

`scripts/check` (bash, run from the repo root, fails on the first problem):

```
scripts/check            lint, then build the package with -warnings-as-errors
scripts/check format     rewrite all Swift files in place
scripts/check lint       lint only (xcrun swift-format lint --strict --recursive)
```

Paths covered: `Screencopy/`, `ScreencopyKit/Sources/`, `ScreencopyKit/Tests/`. Never `.build/`, `DerivedData/`.

`.githooks/pre-commit`, enabled once per clone with `git config core.hooksPath .githooks`:

1. List staged `.swift` files (`git diff --cached --name-only --diff-filter=ACM`). None means exit 0.
2. For each staged file with no unstaged edits: format in place and `git add` it.
3. For a staged file that also has unstaged edits: do not format (it would stage your unfinished hunks). Lint it only.
4. Lint every staged file with `--strict`. Any finding fails the commit and prints the file and rule.

Commits use Conventional Commits (`feat:`, `fix:`, `chore:`, `style:`). The hook does not check the message.

**Replaces**:
- Unformatted code and Xcode's re indent as the only style control.
- Force unwrap (`!`), `try!`, and `Type!` declarations in app and package code.

**Enforcement**:
- Style and the three banned patterns: `swift-format lint --strict`, run by `scripts/check` and by the hook on staged files. Configured in `.swift-format`.
- Compiler warnings: `swift build -Xswiftc -warnings-as-errors` inside `ScreencopyKit/`, in `scripts/check` only. Not in Xcode, not in the hook.
- Commit message wording: convention only, not enforced.

**Rollout**: single migration, in this order so each step is reviewable:
1. `git init` on `main`, commit the current code as is (`chore: initial scaffold`). `.gitignore` already covers `.build/`, `DerivedData/`, `xcuserdata/`.
2. Add `.swift-format`, `scripts/check`, `.githooks/pre-commit`.
3. Run `scripts/check format`, fix the 2 lint findings by hand (wrap the long line; replace the force unwrapped `URL(string:)!` with a guarded lookup), commit as `style: apply swift-format`.
4. Enable the hook. From here new code must comply.

**Exceptions**:
- Tests (`ScreencopyKit/Tests/`) may force unwrap and `try!`.
- Anywhere else, a force unwrap needs a `// swift-format-ignore: NeverForceUnwrap` line comment with a reason beside it. The rule has no other exception.
- Generated files in `Screencopy.xcodeproj` and `Assets.xcassets` are not Swift source and are not touched.

## Constraints the build must honor

- No new dependency beyond the Xcode toolchain, no Homebrew requirement. The hook and script must work on a clean checkout with only Xcode installed.
- `scripts/check` must exit non zero on any finding so `/check verify` and `/develop` can rely on it.
- The hook must never stage lines you did not choose to stage (step 3 of the hook).
- Hook runtime on a typical commit stays around a second. If it grows, the hook has too much in it.

## Consequences

**Positive**:
- One style, zero installs, nothing to version pin.
- The banned crash patterns fail before they land.
- Existing code is nearly compliant, so rollout is a one commit cleanup.

**Negative / tradeoffs**:
- `swift-format` lints less than SwiftLint. Complexity, unused imports, and similar problems are not caught.
- Compiler warnings are not blocked at commit time, because the hook skips the build. A warning is caught the next time `scripts/check` runs (by hand, or in `/develop` and `/check verify`).
- A plain hook can be skipped with `--no-verify`, and must be re enabled on every fresh clone.
- The Xcode app target is not built by `scripts/check`, so warnings only in app target code are not caught by it.

**Neutral**:
- The format commit touches most files once and will show in blame.
- `swift-format` ships with Xcode, so its behavior moves with your Xcode version. Its rule names were checked against Xcode 27.1 today.

## Follow-up

- [ ] Confirm at install that swift-format reads `ScreencopyKit/Tests/.swift-format` for test files. If it does not, pass `--configuration` per directory in `scripts/check` and the hook.
- [ ] Decide later whether `scripts/check` should also build the Xcode app target (`xcodebuild -scheme Screencopy build SWIFT_TREAT_WARNINGS_AS_ERRORS=YES CODE_SIGNING_ALLOWED=NO`). Unverified here, and slower than the package build.
- [ ] Root `AGENTS.md` does not exist. `/audit` should create it with the real stack from spec 0001, these conventions (4 spaces, 120 columns, banned patterns, Conventional Commits, `scripts/check` as the one command), and the `swiftui-expert-skill` pointer.
- [ ] Not enforced by choice: `print` ban, network import ban, doc comments on public API. Revisit if a stray `print` or network call ever appears.
- [ ] Optional skills from spec 0001 still open: `swift-concurrency`, `swift-testing-expert`.
