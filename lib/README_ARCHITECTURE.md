# Sola - Flutter Bible Application Architecture

## Overview

This document describes the clean MVVM architecture of the Sola Flutter Bible application. The codebase is organized into five distinct layers: `core`, `data`, `domain`, `presentation`, and `app`, each with clearly defined responsibilities.

## Architecture Layers

### 1. Core Layer (`lib/core/`)

**Purpose:** Holds all pure data models and session state, with NO Flutter dependencies.

**Components:**
- **Models** (`lib/core/models/`)
  - `translation.dart` - Represents a Bible translation with metadata
  - `book.dart` - Structured Bible book data (Book, Chapter, Verse, VerseData)
  - `page_model.dart` - Represents a single rendered page
  - `index_model.dart` - Verse-to-page index for navigation
  - `rendering_config.dart` - Rendering options and progress data
  - `session_model.dart` - Persistent session state (immutable)
  - `bible_entry.dart` - Legacy translation metadata

- **Session State** (`lib/core/session/`)
  - `session_state.dart` - Observable session state (ChangeNotifier)
  - `session_state_data.dart` - Serializable session state for persistence

### 2. Data Layer (`lib/data/`)

**Purpose:** Handles all data persistence and repository coordination.

**Repositories** (`lib/data/repositories/`)
- `session_repository.dart` - Single source of truth for cross-screen state
- `library_repository.dart` - Translation metadata caching
- `bible_repository.dart` - Serialized book data caching
- `renderer_repository.dart` - Rendered pages and indexes caching
- `search_repository.dart` - Embeddings and search results caching

**Key Pattern:** All repositories use internal caching maps and coordinate with Services to avoid recomputation.

### 3. Domain Layer (`lib/domain/`)

**Purpose:** Contains business logic and service interfaces (NO Flutter imports).

**Services** (`lib/domain/services/`)
- `file_service.dart` - Low-level file I/O
- `bible_service.dart` - USFM parsing and serialization
- `renderer_service.dart` - Page rendering and indexing
- `search_service.dart` - Embedding generation and semantic search

**Use Cases** (`lib/domain/usecases/`) - Orchestrate repositories and services
- Planned: Open Translation, Render Translation, Read Book, Search Verses

### 4. Presentation Layer (`lib/presentation/`)

**Purpose:** MVVM UI boundary - ViewModels and Screens only.

**ViewModels** (`lib/presentation/viewmodels/`)
- `session_viewmodel.dart` - Observes SessionRepository, exposes current state
- `library_viewmodel.dart` - Manages translation library UI state
- `rendering_viewmodel.dart` - Orchestrates rendering configuration and progress
- `reader_viewmodel.dart` - Manages page display and navigation
- `search_viewmodel.dart` - Manages search input and results

**Screens** (`lib/presentation/screens/`)
- `library_screen.dart` - Browse, download, and select translations
- `rendering_config_screen.dart` - Configure and preview rendering
- `reader_screen.dart` - Display pages with pagination
- `search_screen.dart` - Search interface

**Widgets** (`lib/presentation/widgets/`)
- Minimal, reusable UI components (to be styled later)

### 5. App Layer (`lib/app/`)

**Purpose:** Composition root - dependency initialization and routing.

**Components** (Planned)
- `app_bootstrap.dart` - Initialize all dependencies
- `app_dependencies.dart` - Dependency declarations
- `app_routes.dart` - Navigation routing

## Data Flow

### Opening a Translation

```
LibraryScreen
  → LibraryViewModel.openTranslation()
    → SessionRepository.setCurrentTranslation()
    → SessionState notifies listeners
      → Navigation to RenderingConfigurationScreen
```

### Rendering

```
RenderingConfigurationScreen
  → RenderingViewModel.startRendering()
    → RendererRepository.renderAndSave()
      → BibleRepository.getSerializedBook()
      → RendererService.renderBook()
      → RendererService.createVerseIndex()
      → FileService.writeFile() (caching)
      → Progress callbacks
    → SessionRepository.setCurrentBook/Page()
    → Navigation to ReaderScreen
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
          → SearchService.encodeQuery()
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

## Key Architectural Principles

### 1. Single Responsibility
Each component has one reason to change:
- ViewModels manage UI state only
- Repositories handle caching and synchronization
- Services encapsulate algorithms
- Models hold data only

### 2. Dependency Inversion
- ViewModels depend on Repository interfaces, not implementations
- Repositories depend on Service interfaces
- Services are stateless and composable

### 3. Caching Strategy
- Repositories cache computed results in-memory maps
- Caches are invalidated on demand
- All caches are backed by persistent storage

### 4. Observable State
- ViewModels extend ChangeNotifier for reactive updates
- SessionViewModel is the authority for cross-screen state
- UI listens to ViewModels and reacts to changes

### 5. No ViewModel-to-ViewModel Communication
- ViewModels communicate exclusively through SessionRepository
- Eliminates circular dependencies and tight coupling

## Implementation Status

### Completed (Template-Only)
- ✅ Core models and session state
- ✅ Service interfaces
- ✅ Repository templates
- ✅ ViewModel templates

### Pending Implementation
- ⏳ Screen implementations
- ⏳ Use case orchestration
- ⏳ Widget implementations
- ⏳ Dependency injection setup
- ⏳ main.dart entry point

## Design Patterns Used

### Repository Pattern
- Abstracts data sources behind interfaces
- Provides caching layer
- Single point for data access

### ViewModel Pattern (MVVM)
- Separates UI logic from presentation
- Provides observable state to widgets
- Handles user interactions

### Dependency Injection
- Constructor-based injection throughout
- Centralized composition in app layer
- Provider package for runtime wiring

### Observable State
- ChangeNotifier for reactive UI updates
- Listeners notified on state changes
- Minimal rebuilds via Consumer/Provider

## Next Steps for Developers

1. **Understand the Core Models** - Study the data structures in `core/models/`
2. **Implement Services** - Add logic to domain services (algorithms)
3. **Implement Repositories** - Add cache management and persistence
4. **Wire Dependencies** - Create app_bootstrap.dart for dependency injection
5. **Implement Screens** - Build minimal UI with ViewModels
6. **Test** - Add unit and widget tests for each layer

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                       │
│  (LibraryScreen, ReaderScreen, RenderingConfigScreen,     │
│   SearchScreen, Widgets)                                   │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    ViewModel Layer                          │
│  (LibraryVM, ReaderVM, RenderingVM, SearchVM, SessionVM)  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                               │
│  (Repositories: Session, Library, Bible, Renderer, Search) │
│                    (Caching & Persistence)                 │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Domain Layer                             │
│  (Services: File, Bible, Renderer, Search)                 │
│                  (Business Logic - No Flutter)             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Core Layer                               │
│  (Models, Session State - Pure Data)                        │
└─────────────────────────────────────────────────────────────┘
```

---

**Architecture Version:** 1.0  
**Last Updated:** 2026-01-07  
**Flutter:** 3.8.1+  
**Dart:** 3.8.1+
