# C# Coding Style & Standards

The `ScadaWatcherService` and `windows_sync_service` follow standard .NET conventions.

## Standards

1. **Naming**: Use `PascalCase` for classes, methods, and properties. Use `_camelCase` for private fields.
2. **Asynchronous Code**: Always use `async/await` for I/O operations (Firestore, OPC UA, Database).
3. **Thread Safety**: Ensure all services handling shared resources (e.g., `ActiveAlert` list) are thread-safe using `lock`, `SemaphoreSlim`, or concurrent collections.
4. **Dependency Injection**: Use standard .NET dependency injection.

## Project Specifics

- **OPC UA**: Use the `OpcUaClientService` for all tag reading operations.
- **Historian**: All historical data must be persisted via `SqliteHistorianService` before syncing to the cloud.
- **Logging**: Use `ILogger` for all logging; avoid `Console.WriteLine`.
