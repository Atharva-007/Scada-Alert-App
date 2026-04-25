# Flutter Architecture & State Management

The SCADA Alarm Client follows a feature-first architecture with Riverpod for state management.

## Project Structure

- `lib/core/`: Shared services (notifications, theme, sync), utilities, and common widgets.
- `lib/data/`: Data models (Freezed), Firestore integration, and repositories.
- `lib/features/`: Feature modules containing `presentation/` and `providers/`.

## State Management (Riverpod)

1. **Avoid Global State**: Use scoped providers whenever possible.
2. **Immutable Models**: All data models MUST use `Freezed` for immutability.
3. **Provider Selection**:
   - Use `FutureProvider` for one-time async data.
   - Use `StreamProvider` for real-time Firestore updates.
   - Use `NotifierProvider` for complex state transitions.

## UI Performance

- Use `Slivers` and `CustomScrollView` for list views.
- Ensure all animations use `Lottie` or `AnimatedBuilder` for efficiency.
- Target 60/120fps on all devices.
