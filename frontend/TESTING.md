# Testing Documentation

This document outlines the testing strategy, architecture, and instructions for the Homesol App.

## Overview

The project uses `flutter_test` along with `mockito` for unit and widget testing. To ensure components are testable, we've implemented a mockable service pattern for key business logic.

Detailed documentation of implemented test cases for each page can be found in [TEST_CASES.md](TEST_CASES.md).

## Mockable Service Architecture

Key services have been refactored to support dependency injection via a static instance pattern. This allows tests to override the real implementation with a mock.

### Services Supporting Mocking

*   **ShiftService**: Handles attendance actions (Check-In/Check-Out).
*   **UserService**: Manages user profile data and device registration.
*   **AnalyticsService**: Logs screen views and events.

### How to Mock a Service in Tests

1.  **Generate Mocks**: Use `@GenerateNiceMocks` in your test file.
2.  **Set Mock Instance**: Use the `setInstanceForTesting` method in `setUp`.

```dart
@GenerateNiceMocks([MockSpec<ShiftService>()])
void main() {
  late MockShiftService mockShiftService;

  setUp(() {
    mockShiftService = MockShiftService();
    ShiftService.setInstanceForTesting(mockShiftService);
  });

  testWidgets('My Test', (tester) async {
    when(mockShiftService.checkIn(any, any)).thenAnswer((_) async => {'success': true});
    // ... test logic
  });
}
```

## HomePage Enhanced Test Suite

The `test/home_page_enhanced_test.dart` file contains a comprehensive suite of tests for the Home Page, covering:

1.  **Initial UI State**: Correct rendering of basic elements and "Clocked Out" status.
2.  **Shift-Based Button Enablement**: Logic for enabling/disabling "Check In" based on shift hours.
3.  **Late Remark Popup**: Verification that the late reason dialog appears when needed.
4.  **Clock-Out Logic**: Functional check of the check-out flow.
5.  **Location Range Check**: Ensures attendance actions are restricted based on distance from the project.

## Running Tests

### 1. Generate Mocks

Whenever you add new services to `@GenerateMocks` or `@GenerateNiceMocks`, run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Run All Tests

To run all tests in the project:

```bash
flutter test
```

### 3. Run Specific Test File

To run a specific test file:

```bash
flutter test test/home_page_enhanced_test.dart
```

## Best Practices

*   **Use `pump()` vs `pumpAndSettle()`**: For widgets with periodic timers (like `HomePage`), use `pump()` or `pump(duration)` instead of `pumpAndSettle()` to avoid timeout errors from infinite timers.
*   **Mock HTTP Overrides**: Use `HttpOverrides.global` with a custom `HttpClient` mock to prevent real network requests during tests.
*   **Initialize Database FFI**: For tests involving local databases (sqflite), initialize `sqfliteFfiInit()` and set `databaseFactory = databaseFactoryFfi` in `setUpAll`.
*   **Handle didUpdateWidget**: Ensure stateful widgets that depend on parent properties implement `didUpdateWidget` so they correctly react to changes during widget testing.
