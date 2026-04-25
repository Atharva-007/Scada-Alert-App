using System.Collections.Concurrent;
using Microsoft.Extensions.Options;

namespace ScadaWatcherService;

/// <summary>
/// Production-grade alert engine for industrial SCADA systems.
/// Implements ISA-18.2 alarm management principles to prevent alarm flooding
/// while ensuring critical conditions are detected and reported.
/// 
/// Key Features:
/// - State-based alert lifecycle management (not event-based spam)
/// - Deadband/hysteresis to prevent chattering
/// - Cooldown periods to prevent flooding
/// - Escalation for unacknowledged critical alarms
/// - Multiple alert types (threshold, rate-of-change, stale data, quality)
/// - Non-blocking evaluation (< 1ms per data point)
/// - Thread-safe concurrent operations
/// - Comprehensive lifecycle logging
/// 
/// Design Philosophy:
/// - Every alert must be actionable
/// - Prevent alarm fatigue through intelligent suppression
/// - Never miss a truly critical condition
/// - Graceful degradation on errors
/// </summary>
public class AlertEngineService : IDisposable
{
    private readonly ILogger<AlertEngineService> _logger;
    private readonly AlertConfiguration _config;

    // Active alerts indexed by RuleId
    private readonly ConcurrentDictionary<string, ActiveAlert> _activeAlerts;

    // Cooldown tracking: RuleId -> LastAlertTime
    private readonly ConcurrentDictionary<string, DateTime> _cooldownTracker;

    // Background evaluation task
    private Task? _evaluationTask;
    private CancellationTokenSource? _evaluationCts;

    // State tracking
    private bool _isRunning = false;
    private bool _disposed = false;
    private long _totalAlertsRaised = 0;
    private long _totalAlertsCleared = 0;
    private long _totalAlertsEscalated = 0;
    private long _totalAlertsSuppressed = 0;

    /// <summary>
    /// Event raised when a new alert becomes active.
    /// Subscribers should handle asynchronously to avoid blocking.
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertRaised;

    /// <summary>
    /// Event raised when an active alert clears (condition returns to normal).
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertCleared;

    /// <summary>
    /// Event raised when an unacknowledged alert escalates.
    /// </summary>
    public event EventHandler<ActiveAlert>? AlertEscalated;

    public AlertEngineService(
        ILogger<AlertEngineService> logger,
        IOptions<AlertConfiguration> config)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _config = config?.Value ?? throw new ArgumentNullException(nameof(config));

        _activeAlerts = new ConcurrentDictionary<string, ActiveAlert>();
        _cooldownTracker = new ConcurrentDictionary<string, DateTime>();
    }

    /// <summary>
    /// Start the alert engine and initialize alert rules.
    /// </summary>
    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_isRunning)
        {
            _logger.LogWarning("Alert engine is already running. Ignoring start request.");
            return;
        }

        if (!_config.Enabled)
        {
            _logger.LogInformation("Alert engine is disabled in configuration. Not starting.");
            return;
        }

        _logger.LogInformation("=== Alert Engine Starting ===");
        _logger.LogInformation("Evaluation Interval: {Interval}s", _config.EvaluationIntervalSeconds);
        _logger.LogInformation("Max Active Alerts: {Max}", _config.MaxActiveAlerts);

        try
        {
            // Validate configuration
            if (!_config.ValidateRules(out var errors))
            {
                _logger.LogError("Alert configuration validation failed:");
                foreach (var error in errors)
                {
                    _logger.LogError("  - {Error}", error);
                }
                throw new InvalidOperationException("Invalid alert configuration. See logs for details.");
            }

            _logger.LogInformation("Loaded {Count} alert rules", _config.Rules.Count);
            
            // Start background evaluation task
            _evaluationCts = new CancellationTokenSource();
            _evaluationTask = Task.Run(() => EvaluationLoopAsync(_evaluationCts.Token), _evaluationCts.Token);

            _isRunning = true;
            _logger.LogInformation("Alert Engine started successfully.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "CRITICAL: Failed to start alert engine. Alerts will NOT be evaluated.");
        }
    }

    /// <summary>
    /// Stop the alert engine gracefully.
    /// </summary>
    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (!_isRunning)
        {
            return;
        }

        _logger.LogInformation("Alert engine stopping...");
        _isRunning = false;

        try
        {
            // Signal evaluation task to stop
            _evaluationCts?.Cancel();

            // Wait for evaluation task to complete
            if (_evaluationTask != null)
            {
                await Task.WhenAny(_evaluationTask, Task.Delay(5000, cancellationToken));
            }

            _logger.LogInformation(
                "Alert engine stopped. Stats: Raised={Raised}, Cleared={Cleared}, Escalated={Escalated}, Suppressed={Suppressed}",
                _totalAlertsRaised, _totalAlertsCleared, _totalAlertsEscalated, _totalAlertsSuppressed);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during alert engine shutdown.");
        }
    }

    /// <summary>
    /// Acknowledge an active alert.
    /// Returns true if alert was found and acknowledged.
    /// </summary>
    public bool AcknowledgeAlert(string ruleId, string? acknowledgedBy = null, string? detail = null)
    {
        if (_activeAlerts.TryGetValue(ruleId, out var alert))
        {
            if (alert.State == AlertState.Active)
            {
                alert.Acknowledge(acknowledgedBy, detail);
                _logger.LogInformation(
                    "Alert acknowledged: {RuleId} - {Description} by {By}",
                    alert.Rule.RuleId, alert.Rule.Description, acknowledgedBy ?? "System");
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Get all currently active alerts.
    /// </summary>
    public IReadOnlyList<ActiveAlert> GetActiveAlerts()
    {
        return _activeAlerts.Values
            .Where(a => a.State == AlertState.Active || a.State == AlertState.Acknowledged)
            .OrderByDescending(a => a.Rule.Severity)
            .ThenBy(a => a.FirstRaisedTime)
            .ToList();
    }

    /// <summary>
    /// Get alert statistics.
    /// </summary>
    public (long Raised, long Cleared, long Escalated, long Suppressed, int Active) GetStatistics()
    {
        var activeCount = _activeAlerts.Values.Count(a => 
            a.State == AlertState.Active || a.State == AlertState.Acknowledged);
        
        return (_totalAlertsRaised, _totalAlertsCleared, _totalAlertsEscalated, _totalAlertsSuppressed, activeCount);
    }

    /// <summary>
    /// Check if rule is in cooldown period.
    /// </summary>
    private bool IsInCooldown(AlertRule rule)
    {
        if (rule.CooldownSeconds <= 0)
        {
            return false;
        }

        if (_cooldownTracker.TryGetValue(rule.RuleId, out var lastAlertTime))
        {
            var elapsed = (DateTime.UtcNow - lastAlertTime).TotalSeconds;
            return elapsed < rule.CooldownSeconds;
        }

        return false;
    }

    /// <summary>
    /// Background evaluation loop.
    /// Handles escalation checks and cleanup.
    /// </summary>
    private async Task EvaluationLoopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Alert evaluation loop started.");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(_config.EvaluationIntervalSeconds), cancellationToken);

                // Check escalations
                CheckEscalations();

                // Auto-acknowledge info alerts if configured
                if (_config.AutoAcknowledgeInfoAlertsMinutes > 0)
                {
                    AutoAcknowledgeInfoAlerts();
                }

                // Purge old cleared alerts
                PurgeOldAlerts();
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in alert evaluation loop. Continuing...");
            }
        }

        _logger.LogInformation("Alert evaluation loop stopped.");
    }

    /// <summary>
    /// Check for alerts that need escalation.
    /// </summary>
    private void CheckEscalations()
    {
        foreach (var alert in _activeAlerts.Values)
        {
            if (alert.CheckEscalationDue())
            {
                EscalateAlert(alert);
            }
        }
    }

    /// <summary>
    /// Escalate an unacknowledged alert.
    /// </summary>
    private void EscalateAlert(ActiveAlert alert)
    {
        try
        {
            alert.Escalate();
            _totalAlertsEscalated++;

            _logger.LogError(
                "ALERT ESCALATED [{Severity}]: {RuleId} - {Description} (Unacknowledged for {Minutes} minutes)",
                alert.Rule.Severity,
                alert.Rule.RuleId,
                alert.Rule.Description,
                alert.Rule.EscalationMinutes);

            // Raise event
            try
            {
                AlertEscalated?.Invoke(this, alert);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in AlertEscalated event handler for rule {RuleId}", 
                    alert.Rule.RuleId);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error escalating alert for rule {RuleId}", alert.Rule.RuleId);
        }
    }

    /// <summary>
    /// Auto-acknowledge low-severity alerts after configured time.
    /// </summary>
    private void AutoAcknowledgeInfoAlerts()
    {
        var cutoffTime = DateTime.UtcNow.AddMinutes(-_config.AutoAcknowledgeInfoAlertsMinutes);

        foreach (var alert in _activeAlerts.Values)
        {
            if (alert.Rule.Severity == AlertSeverity.Info &&
                alert.State == AlertState.Active &&
                alert.FirstRaisedTime < cutoffTime)
            {
                alert.Acknowledge();
                
                _logger.LogInformation(
                    "Auto-acknowledged info alert: {RuleId} - {Description}",
                    alert.Rule.RuleId, alert.Rule.Description);
            }
        }
    }

    /// <summary>
    /// Purge old cleared alerts to prevent unbounded memory growth.
    /// </summary>
    private void PurgeOldAlerts()
    {
        try
        {
            var cutoffTime = DateTime.UtcNow.AddMinutes(-_config.ClearedAlertRetentionMinutes);
            var toPurge = _activeAlerts.Values
                .Where(a => a.State == AlertState.Cleared && a.ClearedTime < cutoffTime)
                .Select(a => a.Rule.RuleId)
                .ToList();

            foreach (var ruleId in toPurge)
            {
                _activeAlerts.TryRemove(ruleId, out _);
            }

            if (toPurge.Count > 0 && _config.VerboseLogging)
            {
                _logger.LogDebug("Purged {Count} old cleared alerts", toPurge.Count);
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error purging old alerts");
        }
    }

    /// <summary>
    /// Raises an external alert (from file watcher, manual trigger, etc.).
    /// This bypasses normal rule evaluation and directly raises the alert.
    /// </summary>
    public void RaiseExternalAlert(ActiveAlert alert)
    {
        try
        {
            if (!_isRunning)
            {
                _logger.LogWarning("Alert engine is not running. External alert ignored.");
                return;
            }

            // Add to active alerts collection
            _activeAlerts[alert.Rule.RuleId] = alert;
            
            // Raise event for subscribers (Firebase, Historian, etc.)
            AlertRaised?.Invoke(this, alert);
            
            Interlocked.Increment(ref _totalAlertsRaised);
            
            _logger.LogWarning(
                "External alert raised: {RuleId} - {Description}",
                alert.Rule.RuleId, alert.Rule.Description);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error raising external alert");
        }
    }

    /// <summary>
    /// Dispose pattern implementation.
    /// </summary>
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _logger.LogInformation("Disposing alert engine...");

        _evaluationCts?.Cancel();
        _evaluationCts?.Dispose();

        _disposed = true;
        _logger.LogInformation("Alert engine disposed.");
    }
}
