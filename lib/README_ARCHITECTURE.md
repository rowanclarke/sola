# Sola - Flutter Bible Application Architecture

## Overview

This document describes the clean MVVM architecture of the Sola Flutter Bible application. The codebase is organized into four distinct layers: `core`, `data`, `domain`, and `presentation`, plus an `app` composition root. Each layer has clearly defined responsibilities.

## Architecture Layers

### 1. Core Layer (`lib/core/`)

**Purpose:** Holds all pure data models and session state.

**Note:** `PageModel` has a dependency on the Rust FFI package (`package:rust/rust.dart`) because it holds rendered `Text` objects from the Rust backend. This is an accepted pragmatic exception — converting Rust rendering output to Dart-native types would be wasteful.

**Components:**
- **Models** (`lib/core/models/`)
  - `translation.dart` - Represents a Bible translation with metadata (id, title, language, url)
  - `book.dart` - Structured Bible data (Book, Chapter, Verse, VerseData)
  - `page_model.dart` - Represents a single rendered page (wraps Rust `Text` objects)
  - `rendering_config.dart` - Rendering options (fontSize) and progress data
  - `session_model.dart` - Persistent session state (currentTranslationId, currentBookId, currentPageNumber)

- **Session State** (`lib/core/session/`)
  - `session_state.dart` - Observable session state (ChangeNotifier)
  - `session_state_data.dart` - Serializable session state for persistence

### 2. Data Layer (`lib/data/`)

**Purpose:** Handles all data persistence and repository coordination.

**Repositories** (`lib/data/repositories/`)
- `session_repository.dart` - Single source of truth for cross-screen state
- `library_repository.dart` - Translation metadata caching
- `bible_repository.dart` - Serialized book data caching
- `renderer_repository.dart` - Rendered pages caching (index handling is done on the Rust backend)
- `search_repository.dart` - Embeddings and search results caching

**Key Pattern:** All repositories use internal caching maps and coordinate with Services to avoid recomputation.

### 3. Domain Layer (`lib/domain/`)

**Purpose:** Contains business logic and service implementations.

**Services** (`lib/domain/services/`)
- `file_service.dart` - File I/O (string and binary via readBytes/writeBytes)
- `bible_service.dart` - USFM parsing and serialization
- `renderer_service.dart` - Page rendering
- `search_service.dart` - Embedding generation and semantic search

### 4. Presentation Layer (`lib/presentation/`)

**Purpose:** MVVM UI boundary - ViewModels and Screens only.

**ViewModels** (`lib/presentation/viewmodels/`)
- `session_viewmodel.dart` - Observes SessionRepository, exposes current state
- `library_viewmodel.dart` - Manages translation library UI state
- `rendering_viewmodel.dart` - Orchestrates rendering configuration and progress
- `reader_viewmodel.dart` - Manages page display and navigation
- `search_viewmodel.dart` - Manages search input and results

**Navigation:** ViewModels never navigate directly. They expose callbacks that Screens use to trigger navigation. Navigation is always done in Screen code via `Navigator`.

**Screens** (`lib/presentation/screens/`)
- `library_screen.dart` - Browse, download, and select translations
- `rendering_config_screen.dart` - Configure and preview rendering
- `reader_screen.dart` - Display pages with pagination
- `search_screen.dart` - Search interface

**Widgets** (`lib/presentation/widgets/`)
- Minimal, reusable UI components (to be styled later)

### 5. App Layer (`lib/app/`)

**Purpose:** Composition root - dependency initialization and routing.

**Components:**
- `app_bootstrap.dart` - Initialize all dependencies, build provider tree, root widget
- `app_routes.dart` - Navigation routing

## Data Flow

### Opening a Translation

```
LibraryScreen
  → LibraryViewModel.openTranslation()
    → LibraryRepository (download if needed)
    → SessionRepository.setCurrentTranslation()
    → SessionState notifies listeners
    → Screen callback triggers navigation to RenderingConfigScreen
```

### Rendering

```
RenderingConfigScreen
  → RenderingViewModel.startRendering()
    → RendererRepository.renderAndSave()
      → BibleRepository.getSerializedBook()
      → RendererService.renderBook()
      → FileService.writeBytes() (caching)
      → Progress callbacks
    → SessionRepository.setCurrentBook/Page()
    → Screen callback triggers navigation to ReaderScreen
```

### Reading with Search

```
ReaderScreen observes SessionViewModel
  → User swipes to change page
    → ReaderViewModel.goToPage()
      → SessionRepository.setCurrentPage()
      → ReaderViewModel fetches page from RendererRepository
      → Page displayed via PageView

  → User swipes down for search
    → SearchScreen appears
      → SearchViewModel.performSearch()
        → SearchRepository.performSearch()
          → SearchService.performSemanticSearch()
        → Results displayed
        → User selects verse
          → SearchViewModel.selectVerse()
            → SessionRepository updates book & page
          → ReaderScreen observes change and navigates
```

### Session Persistence

```
App Startup
  → SessionRepository.init()
    → FileService.readFile()
    → Restore session state
    → SessionViewModel populated

User Actions
  → SessionRepository.setCurrentTranslation/Book/Page()
    → Updates internal state
    → SessionRepository._persistSession()
      → FileService.writeFile()
```

## Rust Backend

`../rust/lib/rust.dart` contains all the backend functions that the
Dart services need to use. If the Dart services are reporting to
return `String` and Rust reports to use `Pointer<Void>` or `Uint8List`,
keep the Rust implementation.

Verse-to-page indexing is handled entirely by the Rust backend.

## Key Architectural Principles

### 1. Single Responsibility
Each component has one reason to change:
- ViewModels manage UI state only
- Repositories handle caching and synchronization
- Services encapsulate algorithms
- Models hold data only

### 2. Concrete Classes
Services and repositories are concrete classes (not abstract interfaces). This keeps things simple. If testability requires mocking later, interfaces can be extracted then.

### 3. Caching Strategy
- Repositories cache computed results in in-memory maps
- Rendered pages binary and renderer binary are stored via FileService (not the in-memory page cache)
- Caches are invalidated on demand
- Large binary data is encoded via Rust backend for zero-copy deserialisation

### 4. Observable State
- ViewModels extend ChangeNotifier for reactive updates
- SessionViewModel is the authority for cross-screen state
- UI listens to ViewModels and reacts to changes

### 5. No ViewModel-to-ViewModel Communication
- ViewModels communicate exclusively through SessionRepository
- Eliminates circular dependencies and tight coupling

### 6. Navigation in Screens Only
- ViewModels never import Flutter navigation
- ViewModels expose callbacks; Screens handle navigation

## Implementation Status

### Completed (Template-Only)
- Core models and session state
- Service stubs
- Repository stubs
- ViewModel stubs
- AppBootstrap with full dependency wiring

### Pending Implementation
- Screen build() methods
- Widget build() methods
- Service method bodies
- Repository method bodies
- ViewModel method bodies

## Design Patterns Used

### Repository Pattern
- Abstracts data sources behind a single class
- Provides caching layer
- Single point for data access

### ViewModel Pattern (MVVM)
- Separates UI logic from presentation
- Provides observable state to widgets
- Handles user interactions

### Dependency Injection
- Constructor-based injection throughout
- Centralized composition in AppBootstrap
- Provider package for runtime wiring

### Observable State
- ChangeNotifier for reactive UI updates
- Listeners notified on state changes
- Minimal rebuilds via Consumer/Provider

## Next Steps for Developers

1. **Understand the Core Models** - Study the data structures in `core/models/`
2. **Implement FileService** - Add actual file I/O (string + binary)
3. **Implement Services** - Add logic to domain services (delegating to Rust FFI)
4. **Implement Repositories** - Add cache management and persistence
5. **Implement ViewModels** - Add state management and repository calls
6. **Implement Screens** - Build minimal UI with ViewModels
7. **Test** - Add unit and widget tests for each layer

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  (LibraryScreen, ReaderScreen, RenderingConfigScreen,       │
│   SearchScreen, Widgets)                                    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                          │
│  (LibraryVM, ReaderVM, RenderingVM, SearchVM, SessionVM)    │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                               │
│  (Repositories: Session, Library, Bible, Renderer, Search)  │
│                    (Caching & Persistence)                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer                             │
│  (Services: File, Bible, Renderer, Search)                  │
│                  (Business Logic)                           │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Core Layer                               │
│  (Models, Session State - Pure Data)                        │
└─────────────────────────────────────────────────────────────┘
```

---

**Architecture Version:** 2.0
**Last Updated:** 2026-02-16
**Flutter:** 3.8.1+
**Dart:** 3.8.1+
