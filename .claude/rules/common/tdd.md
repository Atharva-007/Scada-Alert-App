# Test-Driven Development (TDD)

All code changes in this project should follow TDD principles to ensure high reliability in industrial SCADA environments.

## Principles

1. **Red-Green-Refactor**: Write a failing test first, then implement the minimal code to make it pass, then refactor.
2. **Coverage**: Aim for 80%+ code coverage for all new features.
3. **Regression Testing**: Fixes for bugs MUST include a reproduction test case.

## Tools

- **Flutter**: Use `flutter test` and `flutter test --coverage`.
- **C#**: Use `dotnet test` with XUnit/NUnit.
