using System.Diagnostics;
using Microsoft.Extensions.Options;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade background worker service that manages a Flutter application process.
/// Implements industrial-reliability patterns for 24/7 SCADA operation.
/// Features: auto-restart, exponential backoff, graceful shutdown, comprehensive logging.
/// 
/// EXTENDED: 
/// - OPC UA SCADA data acquisition (separate internal service)
/// - SQLite historian for data persistence (separate internal service)
/// - Alert engine for alarm management (separate internal service)
/// - Firebase notification adapter for cloud sync and push notifications (separate internal service)
/// All run independently and do not interfere with Flutter process supervision.
/// </summary>
public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly ProcessConfiguration _config;
    private readonly SqliteHistorianService? _historian;
    private readonly AlertEngineService? _alertEngine;
    private readonly NotificationAdapterService? _notificationAdapter;
    
    private Process? _managedProcess;
    private int _restartCount = 0;
    private int _currentRestartDelay;
    private DateTime _lastStartTime = DateTime.MinValue;
    private readonly object _processLock = new object();

    public Worker(
        ILogger<Worker> logger, 
        IOptions<ProcessConfiguration> config,
        SqliteHistorianService? historian = null,
        AlertEngineService? alertEngine = null,
        NotificationAdapterService? notificationAdapter = null)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config?.Value ?? throw new ArgumentNullException(nameof(config));
        _currentRestartDelay = _config.RestartDelaySeconds;
        _historian = historian; // Optional - may be null if historian is disabled
        _alertEngine = alertEngine; // Optional - may be null if alerts are disabled
        _notificationAdapter = notificationAdapter; // Optional - may be null if Firebase is disabled
    }

    /// <summary>
    /// Main execution loop for the background service.
    /// Runs continuously until service shutdown is requested.
    /// </summary>
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("=== ScadaWatcher Service Starting ===");
        _logger.LogInformation("Executable: {Path}", _config.ExecutablePath);
        _logger.LogInformation("Headless Mode: {Headless}", _config.HeadlessMode);
        _logger.LogInformation("Auto-Restart: {AutoRestart}", _config.AutoRestart);

        // Validate configuration before proceeding
        if (!ValidateConfiguration())
        {
            _logger.LogCritical("Configuration validation failed. Service cannot start.");
            return;
        }

        // Wait for Windows system services to initialize
        await DelayStartup(stoppingToken);

        // START ALERT ENGINE (runs independently, non-blocking)
        await StartAlertEngineAsync(stoppingToken);

        // START NOTIFICATION ADAPTER (runs independently, subscribes to alert events)
        await StartNotificationAdapterAsync(stoppingToken);

        // START HISTORIAN (runs independently, non-blocking)
        await StartHistorianAsync(stoppingToken);

        // Main watchdog loop - continues until service shutdown
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await MonitorAndManageProcess(stoppingToken);
            }
            catch (OperationCanceledException)
            {
                // Expected during shutdown - log and exit gracefully
                _logger.LogInformation("Service shutdown requested.");
                break;
            }
            catch (Exception ex)
            {
                // CRITICAL: Never let an unhandled exception terminate the service
                _logger.LogError(ex, "CRITICAL: Unhandled exception in watchdog loop. Service will continue.");
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }

        _logger.LogInformation("=== ScadaWatcher Service Stopping ===");
    }

    /// <summary>
    /// Validates configuration before attempting to start the managed process.
    /// </summary>
    private bool ValidateConfiguration()
    {
        if (string.IsNullOrWhiteSpace(_config.ExecutablePath))
        {
            _logger.LogError("VALIDATION ERROR: ExecutablePath is not configured.");
            return false;
        }

        if (!File.Exists(_config.ExecutablePath))
        {
            _logger.LogError("VALIDATION ERROR: Executable not found at path: {Path}", _config.ExecutablePath);
            return false;
        }

        if (_config.MonitoringIntervalSeconds < 1)
        {
            _logger.LogWarning("VALIDATION WARNING: MonitoringIntervalSeconds is too low. Setting to 5 seconds.");
            _config.MonitoringIntervalSeconds = 5;
        }

        _logger.LogInformation("Configuration validation passed.");
        return true;
    }

    /// <summary>
    /// Delays service startup to allow Windows networking and system services to initialize.
    /// Critical for SCADA environments where network dependencies must be ready.
    /// </summary>
    private async Task DelayStartup(CancellationToken stoppingToken)
    {
        if (_config.StartupDelaySeconds > 0)
        {
            _logger.LogInformation("Waiting {Seconds} seconds for system initialization...", 
                _config.StartupDelaySeconds);
            await Task.Delay(TimeSpan.FromSeconds(_config.StartupDelaySeconds), stoppingToken);
        }
    }

    /// <summary>
    /// Start SQLite historian service if enabled.
    /// Runs independently from OPC UA and Flutter supervision.
    /// Failures here do NOT affect other services.
    /// </summary>
    private async Task StartHistorianAsync(CancellationToken stoppingToken)
    {
        if (_historian == null)
        {
            _logger.LogInformation("Historian service not registered. Skipping historian initialization.");
            return;
        }

        try
        {
            _logger.LogInformation("Starting historian service...");
            
            // Start historian (async, non-blocking)
            await _historian.StartAsync(stoppingToken);
            
            _logger.LogInformation("Historian service started successfully.");
        }
        catch (Exception ex)
        {
            // CRITICAL: Historian failures must NOT crash the service
            _logger.LogError(ex, "Failed to start historian service. Data will NOT be persisted.");
        }
    }

    /// <summary>
    /// Start alert engine service if enabled.
    /// Runs independently from OPC UA, historian, and Flutter supervision.
    /// Failures here do NOT affect other services.
    /// </summary>
    private async Task StartAlertEngineAsync(CancellationToken stoppingToken)
    {
        if (_alertEngine == null)
        {
            _logger.LogInformation("Alert engine not registered. Skipping alert engine initialization.");
            return;
        }

        try
        {
            _logger.LogInformation("Starting alert engine...");
            
            // Register event handlers for alert lifecycle
            _alertEngine.AlertRaised += AlertEngine_AlertRaised;
            _alertEngine.AlertCleared += AlertEngine_AlertCleared;
            _alertEngine.AlertEscalated += AlertEngine_AlertEscalated;
            
            // Start alert engine (async, non-blocking)
            await _alertEngine.StartAsync(stoppingToken);
            
            _logger.LogInformation("Alert engine started successfully.");
        }
        catch (Exception ex)
        {
            // CRITICAL: Alert engine failures must NOT crash the service
            _logger.LogError(ex, "Failed to start alert engine. Alerts will NOT be evaluated.");
        }
    }

    /// <summary>
    /// Start Firebase notification adapter service if enabled.
    /// Runs independently from all other services.
    /// Subscribes directly to alert engine events for cloud sync and push notifications.
    /// Failures here do NOT affect other services.
    /// </summary>
    private async Task StartNotificationAdapterAsync(CancellationToken stoppingToken)
    {
        if (_notificationAdapter == null)
        {
            _logger.LogInformation("Notification adapter not registered. Skipping Firebase initialization.");
            return;
        }

        try
        {
            _logger.LogInformation("Starting notification adapter...");
            
            // Start notification adapter (async, non-blocking)
            // Adapter subscribes directly to alert engine events internally
            await _notificationAdapter.StartAsync();
            
            _logger.LogInformation("Notification adapter started successfully.");
        }
        catch (Exception ex)
        {
            // CRITICAL: Notification adapter failures must NOT crash the service
            _logger.LogError(ex, "Failed to start notification adapter. Cloud sync and push notifications will NOT be available.");
        }
    }

    /// <summary>
    /// Core monitoring and management loop.
    /// Checks process health and restarts if necessary.
    /// </summary>
    private async Task MonitorAndManageProcess(CancellationToken stoppingToken)
    {
        lock (_processLock)
        {
            // Check if the managed process is running
            if (_managedProcess == null || _managedProcess.HasExited)
            {
                if (_managedProcess != null)
                {
                    // Process has crashed or exited
                    int exitCode = 0;
                    try
                    {
                        exitCode = _managedProcess.ExitCode;
                    }
                    catch { /* Process object may be disposed */ }

                    _logger.LogWarning("Process exited with code {ExitCode}. Restart count: {Count}", 
                        exitCode, _restartCount);
                }

                // Start or restart the process
                if (_config.AutoRestart)
                {
                    StartManagedProcess();
                }
                else
                {
                    _logger.LogInformation("Auto-restart is disabled. Process will not be restarted.");
                }
            }
        }

        // Wait before next health check
        await Task.Delay(TimeSpan.FromSeconds(_config.MonitoringIntervalSeconds), stoppingToken);
    }

    /// <summary>
    /// Starts the managed Flutter process with configured settings.
    /// Implements exponential backoff to prevent rapid restart loops.
    /// </summary>
    private void StartManagedProcess()
    {
        try
        {
            // Implement exponential backoff if restarts are happening too quickly
            var timeSinceLastStart = DateTime.UtcNow - _lastStartTime;
            if (timeSinceLastStart.TotalSeconds < 60 && _restartCount > 0)
            {
                // Increase restart delay exponentially
                _currentRestartDelay = Math.Min(
                    _currentRestartDelay * 2, 
                    _config.MaxRestartDelaySeconds);
                
                _logger.LogWarning("Applying exponential backoff: {Delay} seconds before restart.", 
                    _currentRestartDelay);
                
                Thread.Sleep(TimeSpan.FromSeconds(_currentRestartDelay));
            }
            else
            {
                // Reset backoff if process ran successfully for > 60 seconds
                _currentRestartDelay = _config.RestartDelaySeconds;
                _restartCount = 0;
            }

            // Determine working directory
            string workingDir = _config.WorkingDirectory;
            if (string.IsNullOrWhiteSpace(workingDir))
            {
                workingDir = Path.GetDirectoryName(_config.ExecutablePath) ?? string.Empty;
            }

            _logger.LogInformation("Starting process: {Path}", _config.ExecutablePath);
            _logger.LogInformation("Working directory: {Dir}", workingDir);
            _logger.LogInformation("Arguments: {Args}", _config.Arguments ?? "(none)");

            // Configure process start info for headless operation
            var startInfo = new ProcessStartInfo
            {
                FileName = _config.ExecutablePath,
                Arguments = _config.Arguments ?? string.Empty,
                WorkingDirectory = workingDir,
                UseShellExecute = false,
                CreateNoWindow = _config.HeadlessMode,
                RedirectStandardOutput = false,
                RedirectStandardError = false,
                WindowStyle = _config.HeadlessMode ? ProcessWindowStyle.Hidden : ProcessWindowStyle.Normal
            };

            _managedProcess = new Process { StartInfo = startInfo };
            
            // Enable event-based process exit detection
            _managedProcess.EnableRaisingEvents = true;
            _managedProcess.Exited += OnProcessExited;

            if (_managedProcess.Start())
            {
                _lastStartTime = DateTime.UtcNow;
                _restartCount++;
                
                _logger.LogInformation("Process started successfully. PID: {PID}", _managedProcess.Id);
            }
            else
            {
                _logger.LogError("Failed to start process. Process.Start() returned false.");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CRITICAL ERROR: Failed to start managed process.");
            // Service continues running - will retry on next watchdog cycle
        }
    }

    /// <summary>
    /// Handle alert raised events.
    /// </summary>
    private void AlertEngine_AlertRaised(object? sender, ActiveAlert alert)
    {
        _logger.LogWarning("ALERT RAISED: {RuleId} - {Message}", alert.Rule.RuleId, alert.Message);
    }

    /// <summary>
    /// Handle alert cleared events.
    /// </summary>
    private void AlertEngine_AlertCleared(object? sender, ActiveAlert alert)
    {
        _logger.LogInformation("ALERT CLEARED: {RuleId}", alert.Rule.RuleId);
    }

    /// <summary>
    /// Handle alert escalated events.
    /// </summary>
    private void AlertEngine_AlertEscalated(object? sender, ActiveAlert alert)
    {
        _logger.LogError("ALERT ESCALATED: {RuleId}", alert.Rule.RuleId);
    }

    /// <summary>
    /// Event handler for process exit.
    /// Provides real-time notification when the managed process terminates.
    /// </summary>
    private void OnProcessExited(object? sender, EventArgs e)
    {
        if (sender is Process process)
        {
            try
            {
                _logger.LogWarning("Process exit event received. Exit code: {Code}, Exit time: {Time}", 
                    process.ExitCode, process.ExitTime);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Unable to retrieve process exit information.");
            }
        }
    }

    /// <summary>
    /// Gracefully stops the managed process during service shutdown.
    /// Implements timeout-based forceful termination if graceful shutdown fails.
    /// EXTENDED: Also stops alert engine, historian, and notification adapter gracefully.
    /// </summary>
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Service stop requested. Shutting down all services...");

        // STOP ALERT ENGINE FIRST (stop evaluations)
        await StopAlertEngineAsync();

        // STOP NOTIFICATION ADAPTER SECOND (cloud sync and listeners)
        await StopNotificationAdapterAsync();

        // STOP HISTORIAN THIRD (flushes pending data)
        await StopHistorianAsync();

        lock (_processLock)
        {
            if (_managedProcess != null && !_managedProcess.HasExited)
            {
                try
                {
                    _logger.LogInformation("Requesting graceful process shutdown...");
                    
                    // Attempt graceful shutdown via CloseMainWindow
                    _managedProcess.CloseMainWindow();

                    // Wait for graceful shutdown with timeout
                    bool exited = _managedProcess.WaitForExit(_config.ShutdownTimeoutMs);

                    if (!exited)
                    {
                        // Graceful shutdown failed - force termination
                        _logger.LogWarning("Graceful shutdown timeout exceeded. Forcefully terminating process.");
                        _managedProcess.Kill(entireProcessTree: true);
                        
                        // Wait for kill to complete
                        _managedProcess.WaitForExit(2000);
                    }

                    _logger.LogInformation("Managed process terminated successfully.");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error during process shutdown. Process may still be running.");
                    
                    // Last resort: force kill
                    try
                    {
                        if (!_managedProcess.HasExited)
                        {
                            _managedProcess.Kill(entireProcessTree: true);
                        }
                    }
                    catch (Exception killEx)
                    {
                        _logger.LogError(killEx, "Failed to forcefully terminate process.");
                    }
                }
                finally
                {
                    _managedProcess.Dispose();
                    _managedProcess = null;
                }
            }
        }

        await base.StopAsync(cancellationToken);
    }

    /// <summary>
    /// Stop alert engine service gracefully.
    /// Completes current evaluations before stopping.
    /// </summary>
    private async Task StopAlertEngineAsync()
    {
        if (_alertEngine == null)
        {
            return;
        }

        try
        {
            _logger.LogInformation("Stopping alert engine...");
            
            // Stop alert engine
            await _alertEngine.StopAsync();
            
            _logger.LogInformation("Alert engine stopped successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping alert engine.");
        }
    }

    /// <summary>
    /// Stop Firebase notification adapter service gracefully.
    /// Stops cloud sync and acknowledgement listeners.
    /// </summary>
    private async Task StopNotificationAdapterAsync()
    {
        if (_notificationAdapter == null)
        {
            return;
        }

        try
        {
            _logger.LogInformation("Stopping notification adapter...");
            
            // Stop notification adapter
            await _notificationAdapter.StopAsync();
            
            _logger.LogInformation("Notification adapter stopped successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping notification adapter.");
        }
    }

    /// <summary>
    /// Stop SQLite historian service gracefully.
    /// Flushes all pending data before stopping.
    /// </summary>
    private async Task StopHistorianAsync()
    {
        if (_historian == null)
        {
            return;
        }

        try
        {
            _logger.LogInformation("Stopping historian service...");
            
            // Stop historian (will flush pending data)
            await _historian.StopAsync();
            
            _logger.LogInformation("Historian service stopped successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error stopping historian service.");
        }
    }

    /// <summary>
    /// Cleanup resources when the worker is disposed.
    /// </summary>
    public override void Dispose()
    {
        lock (_processLock)
        {
            if (_managedProcess != null)
            {
                try
                {
                    if (!_managedProcess.HasExited)
                    {
                        _managedProcess.Kill(entireProcessTree: true);
                    }
                }
                catch { /* Best effort cleanup */ }
                finally
                {
                    _managedProcess.Dispose();
                    _managedProcess = null;
                }
            }
        }

        base.Dispose();
    }
}
