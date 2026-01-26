# Project Architecture & Guidelines

## 1. Architecture Pattern
This project follows **Clean Architecture** combined with **MVVM (Model-View-ViewModel)** for the presentation layer.

### Layers:
- **Presentation Layer**: Widgets (UI) and ViewModels (State Management).
- **Domain Layer**: Entities, Use Cases, and Repository Interfaces. This layer is independent of external libraries (except core Dart).
- **Data Layer**: Repository Implementations, Data Sources (API, Local DB, Bluetooth), and Models (DTOs).

## 2. Technology Stack
- **Framework**: Flutter (latest stable)
- **Language**: Dart
- **State Management**: Provider (or Riverpod/Bloc as project grows - starting with Provider for simplicity).
- **Dependency Injection**: GetIt
- **Bluetooth**: flutter_blue_plus
- **Permissions**: permission_handler

## 3. Coding Standards (SOLID)
- **S**ingle Responsibility Principle: Each class should have one reason to change.
- **O**pen/Closed Principle: Open for extension, closed for modification.
- **L**iskov Substitution Principle: Subtypes must be substitutable for base types.
- **I**nterface Segregation Principle: Client-specific interfaces are better than one general-purpose interface.
- **D**ependency Inversion Principle: Depend on abstractions, not concretions.

## 4. Testing Strategy (TDD)
- **Unit Tests**: Required for Domain (Use Cases) and Data (Repositories, Models).
- **Widget Tests**: Required for critical UI components.
- **TDD Workflow**: Red (Write failing test) -> Green (Write code to pass) -> Refactor.

## 5. Directory Structure
```
lib/
  core/           # Shared utilities, errors, constants
  features/       # Feature-based organization
    bluetooth/
      data/       # Repositories, Data Sources
      domain/     # Entities, Use Cases, Repository Interfaces
      presentation/ # Widgets, ViewModels (Providers)
  main.dart
```
