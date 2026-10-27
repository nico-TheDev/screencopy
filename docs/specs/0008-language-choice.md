# 0008. Choose the recognition language in Settings

**Date**: 2026-10-28
**Status**: In Progress

## Summary

Settings gets a "Recognition language" menu. It lists Automatic first, then every language Apple's Vision (the on device text reader) can read on your Mac. Pick one language and every capture reads text as that language. Your choice is saved between launches, and a changed choice applies to the very next capture with no restart. If the saved language ever stops being available, captures quietly fall back to Automatic.

## Context

Spec [0004](0004-recognize-and-copy-text.md) fixes recognition to automatic language detection (`languages == nil`) and says feature 6 adds the picker. Detection works for most text but can pick the wrong language for short or mixed snippets, which gives wrong characters or missing accents.

What exists: `VisionTextRecognizer` already accepts `languages: [String]?` and turns detection off when a list is given. `TextCapturePipeline` hardcodes `nil`. `SettingsView` (spec [0005](0005-menu-bar-app-and-settings.md)) has one row, the hotkey. Nothing in the app stores a setting in `UserDefaults` yet (the hotkey is stored by the KeyboardShortcuts library).

Vision's supported language list depends on the macOS version and on the recognition level. The recognizer uses the accurate level, so the list must be asked from a request set up the same way, or the menu could offer a language the recognizer rejects.

## Requirements

**User stories**:
- As the owner, I want to pick the language of the text I capture so that non English text copies with the right characters.
- As the owner, I want my choice remembered so that I set it once.

**Acceptance criteria**:
- **AC-1**: The Settings window has a "Recognition language:" menu below the hotkey row. Its items are "Automatic" first, then every language Vision reports as supported for the accurate level on this Mac. Names are shown in the Mac's preferred language (for example "French (France)"), sorted A to Z in that language, with ties broken by code.
- **AC-2**: The default is Automatic. With Automatic, recognition runs with `languages == nil`, exactly as spec 0004 AC-10 defines.
- **AC-3**: Choosing a language stores its code. The next capture recognizes with that single language (`languages == [code]`, detection off). No restart is needed.
- **AC-4**: The language is read once when a capture starts. Changing the setting while a recognition is running does not change that run.
- **AC-5**: The choice survives quitting and relaunching the app.
- **AC-6**: If the saved code is not in Vision's current list, captures use Automatic, the menu keeps its selection on a disabled item "Unavailable (<code>)", and a note line above the help line reads "Your saved language (<code>) is not available on this Mac, so Automatic is used." The saved code is left untouched until the user picks something, and picking Automatic then clears it (AC-7).
- **AC-7**: Choosing "Automatic" removes the stored code.
- **AC-8**: One help line sits under the menu: "Automatic works for most text. Pick a language if a capture comes out wrong."
- **AC-9**: If Vision's list cannot be read or comes back empty, the menu offers only "Automatic", captures use Automatic, and the failure is logged without any captured content.
- **AC-10**: A capture of printed text in a chosen non English language (for example French with accents) pastes with the right characters.

## Options considered

### Option 1: One language or Automatic, read through a small provider at each capture

A menu of Vision's supported languages plus Automatic. The choice lives in `UserDefaults`. The pipeline asks a `LanguageProviding` value for the current list each time a capture starts.

**Pros**:
- Matches the scope line (pick a language, or let it detect) and is simple to explain and test.
- Changes apply to the next capture without rebuilding anything.
- The provider is a fake in tests; the pipeline keeps no setting state.

**Cons**:
- Mixed language text (for example English prose with Spanish quotes) is read as one language only. Automatic is the answer for that case.

### Option 2: An ordered priority list of languages

Several languages ranked, passed to Vision as a list.

**Pros**:
- Handles mixed text better.

**Cons**:
- Needs add, remove, and reorder UI for a single owner who rarely needs it. More states to test.

### Option 3: Pass the language into `start(image:region:)`

The coordinator reads the setting and hands it over per call.

**Pros**:
- No new protocol.

**Cons**:
- Changes the pipeline signature and its existing tests, and puts setting reads in the coordinator.

## Decision

**Chosen option**: Option 1: One language or Automatic, read through a small provider at each capture.

Settings stores one optional language code in `UserDefaults`. `TextCapturePipeline` takes a `LanguageProviding` and passes its current value to the recognizer at the start of each capture.

## Rationale

The scope asks for one pick or detect, and the recognizer already supports exactly that, so the smallest correct feature is a single optional code. A priority list adds UI that the one owner has no stated need for (spec 0001: boring and small). Reading the value through a provider keeps the pipeline free of storage code and lets tests fake it, which matches the rule that logic lives in `ScreencopyKit` behind protocols. Keeping the saved code when it is unavailable avoids silently throwing away a choice because of a temporary OS difference.

## Feature design

**Data model sketch**:
- One stored setting, no new entity. `UserDefaults` key `recognitionLanguage`: a `String` Vision language code as Vision reports it (for example `fr-FR`, `zh-Hans`). Absent means Automatic. Never an empty string.
- `RecognitionLanguageOption` (value type in `ScreencopyCore`): `code: String`, `name: String`.
- An empty string or a non string value under the key is read as absent (Automatic).

**State transitions**: Automatic (no key) to Language X (key set) to Automatic (key removed). Saved code not supported is a read time view of "Language X", not a stored state.

**API surface** (in process, no network):
| Function | Where | Inputs | Output | Errors |
|---|---|---|---|---|
| `LanguageProviding.languages` | `ScreencopyCore` protocol, `@MainActor` | none | `[String]?` (`nil` means detect) | none |
| `RecognitionLanguages.options(supported:locale:)` | `ScreencopyCore`, pure | `[String]`, `Locale` | `[RecognitionLanguageOption]` sorted by name | none |
| `RecognitionLanguages.resolve(saved:supported:)` | `ScreencopyCore`, pure | `String?`, `[String]` | `[String]?`: `[saved]` if supported, else `nil` | none |
| `VisionTextRecognizer.supportedLanguages()` | `ScreencopyRecognition`, static | none | `[String]`, empty on failure | logs (category `settings`, level error, error description only), returns `[]` |
| `LanguageSettings` (conforms to `LanguageProviding`) | `Screencopy` app, an `@MainActor @Observable` class | `UserDefaults`, supported list | current `[String]?`; stored `savedCode: String?` mirroring the key; `select(_:)` | none |
| `TextCapturePipeline.init(..., languages:)` | `ScreencopyCore` | adds a `LanguageProviding` | n/a | n/a |

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| Open Settings | List of language codes | `VisionTextRecognizer.supportedLanguages()`: a `VNRecognizeTextRequest` with `recognitionLevel = .accurate` and the default revision (the same setup the recognizer uses), fetched synchronously once in `applicationDidFinishLaunching`, before the pipeline is built, and cached. The recognizer and this query build their request through one shared helper so level and revision cannot drift apart |
| Open Settings | Language names | A locale built from `Locale.preferredLanguages.first` (fallback "en"), the same one passed to `options(supported:locale:)` for names and sorting; `localizedString(forIdentifier: code)`, or the code itself if `nil`. Ties sort by code |
| Open Settings | Selected item | `LanguageSettings.savedCode`: Automatic if `nil`, the language if supported, else the disabled "Unavailable (<code>)" item |
| Open Settings | Unsupported note text | Saved code from the same key, inserted into the AC-6 sentence |
| Start a capture | `languages` passed to the recognizer | `LanguageProviding.languages`, from the key and the cached supported list via `resolve` |
| Choose a language | Stored value | The code of the chosen option; Automatic removes the key |

**View wiring**: `AppDelegate` creates one `LanguageSettings` and passes it to the pipeline and to `SettingsView(hotkey:languages:)`. The menu is a `Picker("Recognition language:", ...)` bound to `String?` (Automatic tagged `nil`), menu style, `.fixedSize()`, inside the existing `VStack` (12 points spacing). The note, when shown, comes first, then the help line, both `.callout` and `.secondary` like the existing help lines. No `@AppStorage`.

**Key invariants**:
- A language is only ever sent to Vision if it is in the current supported list. Otherwise `nil` is sent.
- `languages == nil` is the only way to turn detection on; a non nil list always turns it off (existing behavior in `VisionTextRecognizer`).
- The language is read once per capture start, into a local `let` before the task is created, and never again for that run.
- Captured text and images are never logged. The language code may be logged.

**Security model**: Local only. The setting is a language code in the app's own preferences. No network, no account, no regulated data.

**Configuration required**: none.

**Critical test scenarios**:
- Pipeline passes the provider's current value to the recognizer, and `nil` for Automatic, verifies **AC-2**, **AC-3**
- Provider value changes after a run starts, the running call still used the old value, verifies **AC-4**
- `resolve` returns `nil` for a code not in the list and `[code]` for one that is, verifies **AC-3**, **AC-6**
- `options` puts nothing before Automatic (UI adds it first), sorts by name in the given locale, and falls back to the code when no name exists, verifies **AC-1**
- Empty supported list gives `nil` and an Automatic only menu, verifies **AC-9**
- Selecting Automatic removes the key; selecting a language sets it; a fresh `LanguageSettings` on the same defaults reads it back, verifies **AC-5**, **AC-7**
- `LanguageSettings` tests use a throwaway `UserDefaults` suite named with a UUID, removed on teardown; `FakeLanguageProvider` is `@MainActor`
- Manual: capture French text with accents under Automatic and under French, verifies **AC-10**

## Build plan

The project default is Skateboard: the smallest complete version first. Here that is a working picker end to end, since the feature is tiny.

1. `ScreencopyCore`: add `LanguageProviding`, `RecognitionLanguageOption`, and `RecognitionLanguages.options` and `.resolve`, with unit tests, satisfies **AC-1**, **AC-2**, **AC-6**, **AC-9**
2. `TextCapturePipeline`: take a `LanguageProviding`, read it once in `start` before the task begins, pass it to `recognize`; update the test fakes (`FakeTextRecognizer` records the languages it received) and the pipeline tests, satisfies **AC-2**, **AC-3**, **AC-4**
3. `ScreencopyRecognition`: add static `VisionTextRecognizer.supportedLanguages()` and a shared request helper used by both it and `recognize` (accurate level, default revision; returns `[]` and logs on failure), satisfies **AC-1**, **AC-9**
4. App: add `LanguageSettings` (`UserDefaults` key `recognitionLanguage`, supported list fetched at launch, conforms to `LanguageProviding`) and give the pipeline in `AppDelegate` and `SettingsView` the same instance, satisfies **AC-2**, **AC-3**, **AC-5**, **AC-7**
5. `SettingsView`: add the "Recognition language:" menu with the "Unavailable" item, the note, and the help line below the hotkey row; keep the window 400 points wide with height fitting its content, satisfies **AC-1**, **AC-6**, **AC-8**
6. Manual check with real French text, then update spec [0004](0004-recognize-and-copy-text.md) AC-10 wording if needed, satisfies **AC-10**

## Consequences

**Positive**:
- Non English text can be forced to the right language when detection guesses wrong.
- The pipeline stays free of storage code and easy to test.
- A temporary OS difference never destroys the saved choice.

**Negative / tradeoffs**:
- One language per capture. Mixed language text should use Automatic.
- With a fixed language, words from another language may be read poorly.
- The supported list is read once per launch, so an OS language pack change shows up after relaunch.
- The Settings window grows taller than spec 0005's single row layout.

**Neutral**:
- First use of `UserDefaults` for an app setting. The hotkey stays with the KeyboardShortcuts library.
- Spec 0004 says the language is "Fixed `nil`" in Release 1. This spec makes `nil` the default instead of the only value.
- `VNRecognizeTextRequest` stays in use (spec 0001). If it is later replaced by `RecognizeTextRequest`, only `VisionTextRecognizer` changes.

## Follow-up

- [ ] Spec 0004's Decision table row "Languages: Fixed `nil`" is out of date once this ships. Reconcile it with `/sync`.
- [ ] Spec 0003's note that hint text is English only still stands. Localizing the app's own text is not part of this feature.
