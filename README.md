# Source Shelf

> Offline research source cabinet: capture references, page-specific quotes, and citation-ready notes on phone, tablet, and Windows without accounts.

Source Shelf is a planned local-first, multi-platform research workspace for independent researchers, students, writers, and journalists. Goal: store books, articles, reports, primary documents, and interviews on your device, capture exact page citations and excerpt notes, then export citation-ready BibTeX/JSON and formatted snippets without accounts or trackers.

Flutter 3.47.7 project generated for Windows desktop, Android phones/tablets, and iPhones/iPads. Current app is an adaptive empty state only; source capture, persistence, citation drafts, exports, icon wiring, and release packaging remain planned.

---

## Motivation

Research workflows on mobile and desktop are heavily fragmented:
1. Reference managers (Zotero, Mendeley, EndNote) are heavy, desktop-centric, or push users into cloud accounts and subscription sync.
2. Note-taking apps (Apple Notes, Obsidian, Notion) hold freeform text but lack structured citation metadata (authors, year, publisher, DOI/ISBN, edition, page ranges, exact quote attribution).
3. Mobile scanner/read-later apps trap snippets behind proprietary logins without clean citation exports.

Source Shelf bridges this gap: a clean, local-first card cabinet and reading log designed for capturing accurate evidence while reading physical books, PDFs, or articles on any device.

---

## Target Users

- **Students & Academics**: Capture quotes and page numbers while reading in libraries or classrooms; export formatted bibliographies into essays.
- **Writers & Authors**: Keep non-fiction source binders organized by topic, edition, and exact quote citations.
- **Journalists & Independent Researchers**: Verify source material offline with immutable capture dates and full local data ownership.
- **Lifelong Readers**: Track memorable book excerpts and retain structured reading notes without cloud subscriptions.

---

## Concrete Use Cases

- **Library Book Reading**: Read a physical library book, record author/title/ISBN/year, and log 6 exact page quotes with personal commentary before returning the loan.
- **Journal Article Excerpting**: Record an academic paper's DOI, container journal, volume, issue, and key findings; copy an APA 7th or BibTeX block with one tap.
- **Multi-Device Research**: Draft citation notes on an Android tablet or iPhone during transit, export a standard JSON or BibTeX bundle, and import it into Source Shelf on Windows.
- **Primary Source Interview Archive**: Document interviewees, dates, transcripts, and excerpt cards with custom tags (e.g., `#chapter3`, `#archival-doc`).

---

## Features (MVP)

- **Source Catalog**: Create, view, search, and edit source entries (Book, Journal Article, Book Section / Chapter, Web Document, Archival Document, Interview).
- **Core Metadata Fields**: Title, creators/authors (ordered list), publication year, container/publisher, volume/issue, edition, ISBN/DOI, call number, and shelf tags.
- **Page-Specific Excerpts & Notes**: Attach timestamped excerpt cards to each source with exact page / page-range locator, verbatim quote, commentary note, and tags.
- **Citation Formatter Engine**: Deterministic APA 7 and BibTeX drafts with missing-field warnings; Chicago, MLA, and Harvard are post-MVP candidates.
- **Local Collections & Tags**: Organize sources into user-defined collections (e.g., *Thesis Chapter 2*, *19th Century Maritime*) and searchable tags.
- **Adaptive Layout**: Optimized for touch on phone, split-pane on tablet, and multi-column workspace with keyboard shortcuts on Windows desktop.
- **Backup & Export**: Full database export to JSON, BibTeX (`.bib`), and Markdown source cards with one-tap clipboard copy or file export.
- **Zero Cloud / Zero Network**: Works 100% offline with no accounts, telemetry, or external API requirements.

---

## Explicit Non-Goals

- No PDF cloud-sync or hosted reader service (PDF attachments, if added later, remain local files).
- No proprietary cloud synchronization service, user accounts, or login screens.
- No auto-scraping behind paywalls or automated web browsing bots.
- No social feeds, public profile sharing, or multi-user live collaborative document editing.
- No AI hallucinations for citations: formatting is 100% deterministic code following published style manuals.
- No cross-platform UI frameworks outside Flutter (no React Native, Expo, Kotlin Multiplatform, Unity, or .NET MAUI).

---

## Privacy, Permissions & Storage

- **Data Ownership**: All source entries, excerpts, and tags live in a local SQLite / file-backed database on the host device.
- **Network Access**: None. The app declares no network permissions and makes no outbound requests.
- **Device Permissions**: Only file picker access when explicitly saving an export file or importing a backup.
- **Telemetry**: Zero crash reporting SDKs, zero analytics trackers, zero ad libraries.

---

## Platform & UX Strategy

Source Shelf plans **Strategy A: Platform-Native Adaptive UX**:
- **iOS & iPadOS**: Cupertino design language, native navigation bars, large titles, modal sheets, swipe-back, and iOS keyboard behavior.
- **Android**: Material 3 with dynamic color tokens, navigation rail / bottom navigation, and Android system predictive back.
- **Windows Desktop**: Fluent UI design system with title bar integration, command bar, NavigationView, hover states, context menus, and keyboard shortcuts (`Ctrl+N`, `Ctrl+F`, `Ctrl+E`).

---

## App Store & Identifiers

- **Identifier**: `com.infinityball.sourceshelf`
- **Windows Identity**: `cominfinityball.sourceshelf`
- **Target Device Families**: Phone, Tablet, Desktop (Windows 10/11, Android 7+, iOS 16+)
- **Store Description**: `AppStore/description.txt`
- **Icon**: `AppStore/icon.png` (1024x1024 generated via OpenAI Images API)

### Manual Setup Required

The App Store Connect bundle ID registration returned:
```text
FAILED bundleId lookup rejected: FORBIDDEN_ERROR.PLA_NOT_ACCEPTED
```
The developer account Program License Agreement (PLA) must be accepted by the account owner in Apple Developer portal before bundle ID `com.infinityball.sourceshelf` can be registered via API.

---

## Development Quickstart

Pin Flutter 3.47.7 (Dart 3.13.5). Current screen is an empty-state skeleton; no research records can be saved yet. Windows identity `cominfinityball.sourceshelf` applies to future MSIX packaging, not current portable runner. iOS compilation requires macOS/Xcode and is not gated yet.

```bash
# Verify Flutter toolchain (3.47.7) and lockfile
flutter pub get --enforce-lockfile
# Verify Flutter toolchain
flutter --version

# Run tests
flutter test

# Run desktop build (Windows)
flutter build windows --release

# Run Android debug build
flutter build apk --debug
```
