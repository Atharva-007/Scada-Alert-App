# SCADA Watcher Service - Technical Architecture

## INDUSTRIAL-RELIABILITY DESIGN PATTERNS

This document explains the technical implementation and design decisions for the production-grade SCADA Watcher Service.

---

## CORE DESIGN PRINCIPLES

### 1. Fail-Safe Operation
**Principle**: The service must never crash, regardless of external conditions.

**Implementation**:
- All exceptions caught and logged at every level
- Try-catch blocks around critical operations
- Watchdog loop wrapped in exception handler
- Process management operations isolated with locks

**Code Example** (Worker.cs):
```csharp
while (!stoppingToken.IsCancellationRequested)
{
    try
    {
        await MonitorAndManageProcess(stoppingToken);
    }
    catch (OperationCanceledException)
    {
        // Expected during shutdown
        break;
    }
    catch (Exception ex)
    {
        // CRITICAL: Never let unhandled exception terminate service
        _logger.LogError(ex, "Unhandled exception in watchdog loop");
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
    }
}
```

### 2. Self-Healing Behavior
**Principle**: Automatically recover from failures without manual intervention.

**Implementation**:
- Continuous process health monitoring
- Automatic restart on crash detection
- Exponential backoff to prevent rapid loops
- Event-based and polling-based detection

**Restart Logic**:
1. Process exits → Detected via `HasExited` property
2. Calculate time since last start
3. Apply exponential backoff if < 60 seconds
4. Restart with configured delay
5. Reset backoff if process runs > 60 seconds

### 3. Defensive Programming
**Principle**: Validate everything, assume nothing.

**Implementation**:
```csharp
private bool ValidateConfiguration()
{
    if (string.IsNullOrWhiteSpace(_config.ExecutablePath))
    {
        _logger.LogError("ExecutablePath is not configured.");
        return false;
    }
    
    if (!File.Exists(_config.ExecutablePath))
    {
        _logger.LogError("Executable not found: {Path}", _config.ExecutablePath);
        return false;
    }
    
    // Additional validation...
    return true;
}
```

### 4. Graceful Degradation
**Principle**: Continue operating even when components fail.

**Implementation**:
- Service continues if process fails to start
- Retry mechanisms with backoff
- Logging failures without terminating service
- Configuration reload without restart

---

## COMPONENT ARCHITECTURE

### Program.cs - Service Host

**Responsibilities**:
1. Configure Serilog logging infrastructure
2. Load configuration from JSON files
3. Register dependency injection services
4. Enable Windows Service integration
5. Handle fatal startup errors

**Key Code Sections**:

```csharp
// Early logging configuration - before host build
var loggingConfig = tempConfig.GetSection("Logging").Get<LoggingConfiguration>();
Log.Logger = new LoggerConfiguration()
    .WriteTo.File(/* rotation settings */)
    .CreateLogger();

// Windows Service integration - CRITICAL
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "ScadaWatcherService";
});
```

**Why Early Logging?**
- Capture startup failures before DI container exists
- Ensure all errors are logged, even configuration errors
- Provide audit trail from first moment of execution

### Worker.cs - Process Manager

**Responsibilities**:
1. Validate configuration on startup
2. Implement startup delay for network initialization
3. Monitor process health continuously
4. Restart crashed processes with backoff
5. Gracefully shutdown managed process

**State Management**:
```csharp
private Process? _managedProcess;          // Current process instance
private int _restartCount = 0;             // Track restart attempts
private int _currentRestartDelay;          // Exponential backoff value
private DateTime _lastStartTime;           // For backoff calculation
private readonly object _processLock;      // Thread safety
```

**Thread Safety**:
All process operations wrapped in `lock (_processLock)` to prevent race conditions during concurrent access (e.g., shutdown during restart).

### ProcessConfiguration.cs - Configuration Models

**Responsibilities**:
1. Define strongly-typed configuration structure
2. Provide default values
3. Document all parameters
4. Support dependency injection

**Benefits**:
- Compile-time type checking
- IntelliSense support
- Validation at binding time
- Clear documentation of all settings

---

## RELIABILITY MECHANISMS

### 1. Exponential Backoff

**Problem**: Rapidly restarting a failing process wastes resources and may mask underlying issues.

**Solution**: Increase delay between restart attempts exponentially.

```csharp
if (timeSinceLastStart.TotalSeconds < 60 && _restartCount > 0)
{
    // Double delay up to maximum
    _currentRestartDelay = Math.Min(
        _currentRestartDelay * 2, 
        _config.MaxRestartDelaySeconds);
}
else
{
    // Reset if process ran successfully > 60 seconds
    _currentRestartDelay = _config.RestartDelaySeconds;
    _restartCount = 0;
}
```

**Backoff Sequence** (with defaults):
- 1st restart: 10 seconds
- 2nd restart: 20 seconds
- 3rd restart: 40 seconds
- 4th restart: 80 seconds
- 5th restart: 160 seconds
- 6th+ restart: 300 seconds (capped)

### 2. Dual Process Monitoring

**Event-Based Detection**:
```csharp
_managedProcess.EnableRaisingEvents = true;
_managedProcess.Exited += OnProcessExited;
```

**Polling-Based Detection**:
```csharp
if (_managedProcess.HasExited)
{
    // Restart logic
}
```

**Why Both?**
- Events provide immediate notification
- Polling catches missed events
- Redundancy for critical functionality

### 3. Graceful Shutdown with Timeout

**Three-Stage Shutdown**:

```csharp
// Stage 1: Request graceful shutdown
_managedProcess.CloseMainWindow();

// Stage 2: Wait with timeout
bool exited = _managedProcess.WaitForExit(_config.ShutdownTimeoutMs);

// Stage 3: Force kill if timeout exceeded
if (!exited)
{
    _managedProcess.Kill(entireProcessTree: true);
    _managedProcess.WaitForExit(2000);
}
```

**Why This Matters**:
- Allows process to save state/cleanup
- Prevents orphaned child processes
- Ensures service stops promptly
- No hung shutdown scenarios

### 4. Startup Delay for Dependencies

**Problem**: Service may start before network/database services are ready.

**Solution**: Configurable startup delay.

```csharp
if (_config.StartupDelaySeconds > 0)
{
    _logger.LogInformation("Waiting {Seconds} seconds for system initialization", 
        _config.StartupDelaySeconds);
    await Task.Delay(TimeSpan.FromSeconds(_config.StartupDelaySeconds), stoppingToken);
}
```

**Recommended Values**:
- Local applications: 5-10 seconds
- Network-dependent apps: 15-30 seconds
- Database-dependent apps: 30-60 seconds

---

## LOGGING ARCHITECTURE

### Serilog Configuration

**Why Serilog?**
- Structured logging (JSON-compatible)
- High performance (async writes)
- Built-in rotation and retention
- Rich formatting options
- Production-proven reliability

**Dual Sinks**:
```csharp
.WriteTo.Console(/* for debugging */)
.WriteTo.File(/* for production */)
```

**Rotation Strategy**:
- **Daily**: New file at midnight (RollingInterval.Day)
- **Size-based**: When file exceeds 50MB
- **Retention**: Keep 30 most recent files
- **Automatic cleanup**: Old files deleted

### Log Enrichment

```csharp
.Enrich.WithMachineName()    // Which server?
.Enrich.WithProcessId()      // Which service instance?
.Enrich.WithThreadId()       // Which thread (for debugging)?
```

**Benefits**:
- Identify source in multi-server environments
- Correlate events across log files
- Debug concurrency issues

### Log Levels

| Level | When to Use | Examples |
|-------|-------------|----------|
| **Information** | Normal operations | Service start, process start, health checks |
| **Warning** | Recoverable issues | Process exit, restart attempts, backoff |
| **Error** | Failures requiring attention | Startup failures, configuration errors |
| **Critical** | Service-threatening failures | Fatal exceptions, validation failures |

---

## WINDOWS SERVICE INTEGRATION

### UseWindowsService() vs Manual Implementation

**Legacy Approach** (manual):
```csharp
class MyService : ServiceBase
{
    // Complex lifecycle management
    // Manual SCM communication
}
```

**Modern Approach** (.NET 8):
```csharp
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "ScadaWatcherService";
});
```

**Benefits**:
- Automatic SCM integration
- Handles service lifecycle events
- Compatible with BackgroundService pattern
- Minimal boilerplate code

### Service Control Manager (SCM) Events

The service responds to:
- **Start**: Triggers `ExecuteAsync()`
- **Stop**: Triggers `StopAsync()` → cancellation token
- **Pause/Resume**: Not implemented (continuous operation required)

### Auto-Start Configuration

```powershell
sc.exe config ScadaWatcherService start= delayed-auto
```

**Why Delayed-Auto?**
- Waits for network initialization
- Reduces boot time impact
- Ensures dependencies are ready
- Standard for server applications

---

## HEADLESS MODE IMPLEMENTATION

### ProcessStartInfo Configuration

```csharp
var startInfo = new ProcessStartInfo
{
    FileName = _config.ExecutablePath,
    UseShellExecute = false,          // Direct process creation
    CreateNoWindow = true,             // No console window
    WindowStyle = ProcessWindowStyle.Hidden,  // No UI window
    RedirectStandardOutput = false,    // No output capture (performance)
    RedirectStandardError = false
};
```

**Key Settings**:
- `CreateNoWindow`: Prevents console window
- `WindowStyle.Hidden`: Hides GUI windows
- `UseShellExecute = false`: Required for headless mode

**Flutter-Specific Considerations**:
- Flutter Windows apps support headless mode
- May require `--headless` argument (app-dependent)
- Some UI frameworks require display buffer even when hidden

---

## CONFIGURATION MANAGEMENT

### Multi-Environment Support

**File Hierarchy**:
1. `appsettings.json` - Base configuration (production defaults)
2. `appsettings.Development.json` - Development overrides
3. Environment variables - Runtime overrides

**Loading Order** (last wins):
```csharp
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile($"appsettings.{env}.json", optional: true)
    .AddEnvironmentVariables();
```

### Options Pattern

**Dependency Injection**:
```csharp
builder.Services.Configure<ProcessConfiguration>(
    builder.Configuration.GetSection("ProcessManagement"));
```

**Usage in Worker**:
```csharp
public Worker(IOptions<ProcessConfiguration> config)
{
    _config = config.Value;
}
```

**Benefits**:
- Type-safe configuration access
- Automatic binding and validation
- Testable (mock IOptions)
- Supports configuration reload

---

## PERFORMANCE CONSIDERATIONS

### Resource Usage

**Memory**:
- Service baseline: ~20-30 MB
- Per managed process: Depends on Flutter app
- Logging: Minimal (async writes)

**CPU**:
- Idle: < 0.1%
- Monitoring loop: < 0.5%
- Process start/stop: Brief spike

**Disk I/O**:
- Logs: 1-5 MB/day (typical)
- Rotation: Automatic, non-blocking

### Optimization Strategies

1. **Async Operations**: All delays use `async Task.Delay()`
2. **No Output Redirection**: Process output not captured (performance)
3. **Efficient Polling**: 5-second intervals (configurable)
4. **Lock Minimization**: Critical sections kept small

---

## TESTING STRATEGY

### Unit Testing Approach

**Testable Components**:
```csharp
// Mock configuration
var mockConfig = new Mock<IOptions<ProcessConfiguration>>();
mockConfig.Setup(c => c.Value).Returns(new ProcessConfiguration { /* test values */ });

// Mock logger
var mockLogger = new Mock<ILogger<Worker>>();

// Test worker
var worker = new Worker(mockLogger.Object, mockConfig.Object);
```

### Integration Testing

**Manual Test Scenarios**:
1. Install service → Verify auto-start on boot
2. Stop Flutter app → Verify auto-restart
3. Kill Flutter process → Verify detection and restart
4. Stop service → Verify graceful Flutter shutdown
5. Invalid config → Verify validation errors logged
6. Rapid restarts → Verify exponential backoff

### Production Validation

**Monitoring Checklist**:
- [ ] Service starts after server reboot
- [ ] Logs written to correct directory
- [ ] Process restarts after crash
- [ ] Backoff increases on repeated failures
- [ ] Service responds to SCM commands
- [ ] Graceful shutdown completes < 10 seconds

---

## SECURITY HARDENING

### Least Privilege Principle

**Recommended Service Account**:
- Create dedicated service account
- Grant minimal permissions:
  - Read/Execute: Flutter executable directory
  - Write: Log directory only
  - No admin privileges required

**Example**:
```powershell
sc.exe config ScadaWatcherService obj= "NT SERVICE\ScadaWatcherService"
```

### Path Injection Prevention

**Always use absolute paths**:
```csharp
if (!Path.IsPathFullyQualified(_config.ExecutablePath))
{
    _logger.LogError("ExecutablePath must be absolute");
    return false;
}
```

### Secure Configuration

**Protect appsettings.json**:
```powershell
# Remove unnecessary permissions
icacls "appsettings.json" /inheritance:r
icacls "appsettings.json" /grant:r "SYSTEM:(R)"
icacls "appsettings.json" /grant:r "Administrators:(R)"
```

---

## FUTURE ENHANCEMENTS

### Potential Additions

1. **Multiple Process Management**
   - Support array of executables in configuration
   - Independent monitoring for each process

2. **Health Check Endpoints**
   - HTTP endpoint for monitoring systems
   - Return service status, process status, uptime

3. **Performance Metrics**
   - Track restart frequency
   - Monitor process memory/CPU usage
   - Alert on anomalies

4. **Remote Management**
   - REST API for control operations
   - Start/stop processes via API
   - Update configuration dynamically

5. **Process Communication**
   - Named pipes for IPC
   - Send commands to managed process
   - Receive health status from process

---

## TROUBLESHOOTING GUIDE

### Common Issues

**Issue**: Service installs but won't start
- **Cause**: Missing dependencies, invalid configuration
- **Solution**: Check Event Viewer, validate appsettings.json

**Issue**: Process restarts continuously
- **Cause**: Flutter app crashes immediately
- **Solution**: Test Flutter app manually, check app logs

**Issue**: Service doesn't restart process
- **Cause**: `AutoRestart` disabled or process not detected as exited
- **Solution**: Verify configuration, check process monitoring logs

**Issue**: Logs not being written
- **Cause**: Permission denied on log directory
- **Solution**: Grant write permissions to service account

---

## CONCLUSION

This service implements industrial-grade reliability through:
- **Defensive programming**: Every failure scenario handled
- **Self-healing**: Automatic recovery without intervention
- **Comprehensive logging**: Full audit trail of all operations
- **Graceful degradation**: Continues operating despite failures
- **Production-ready**: Designed for 24/7 operation

The architecture prioritizes **stability over features**, ensuring the service never crashes and always recovers from failures automatically.
