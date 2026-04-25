using System.ComponentModel.DataAnnotations;

namespace ScadaWatcherService;

/// <summary>
/// Configuration model for Firebase cloud integration.
/// Binds to the "Firebase" section in appsettings.json.
/// </summary>
public class FirebaseConfiguration
{
    public const string ServiceAccountEnvVar = "FIREBASE_SERVICE_ACCOUNT_JSON";
    public const string GoogleCredentialsEnvVar = "GOOGLE_APPLICATION_CREDENTIALS";

    /// <summary>
    /// Enables or disables the Firebase notification adapter.
    /// If disabled, all cloud synchronization and push notifications are suppressed.
    /// </summary>
    public bool Enabled { get; set; } = false;

    /// <summary>
    /// Google Cloud project ID (e.g., "scadadataserver").
    /// </summary>
    [Required]
    public string ProjectId { get; set; } = string.Empty;

    /// <summary>
    /// Path to the Firebase service account JSON key file.
    /// Relative paths are resolved from the deployed service folder.
    /// Example: "config\\firebase-service-account.json"
    /// </summary>
    [Required]
    public string ServiceAccountJsonPath { get; set; } = string.Empty;

    /// <summary>
    /// Firestore collection name for active alerts.
    /// Default: "alerts_active"
    /// </summary>
    public string ActiveAlertsCollection { get; set; } = "alerts_active";

    /// <summary>
    /// Firestore collection name for cleared/historical alerts.
    /// Default: "alerts_history"
    /// </summary>
    public string HistoryAlertsCollection { get; set; } = "alerts_history";

    /// <summary>
    /// Firestore collection name for alert event audit trail (optional).
    /// Default: "alert_events"
    /// </summary>
    public string EventsCollection { get; set; } = "alert_events";

    /// <summary>
    /// Firestore collection name for device tokens (for targeted push notifications).
    /// Default: "device_tokens"
    /// </summary>
    public string DeviceTokensCollection { get; set; } = "device_tokens";

    /// <summary>
    /// Firebase Cloud Messaging topic for broadcasting alerts.
    /// All mobile devices subscribe to this topic.
    /// Default: "scada_alerts"
    /// </summary>
    public string NotificationTopic { get; set; } = "scada_alerts";

    /// <summary>
    /// Enable push notifications for Info-severity alerts.
    /// Default: false (Info alerts only sync to Firestore)
    /// </summary>
    public bool SendNotificationsForInfo { get; set; } = false;

    /// <summary>
    /// Enable push notifications for Warning-severity alerts.
    /// Default: true
    /// </summary>
    public bool SendNotificationsForWarning { get; set; } = true;

    /// <summary>
    /// Enable push notifications for Critical-severity alerts.
    /// Default: true
    /// </summary>
    public bool SendNotificationsForCritical { get; set; } = true;

    /// <summary>
    /// Minimum seconds between notifications for the same alert (throttling).
    /// Prevents notification spam if alert re-raises rapidly.
    /// Default: 300 seconds (5 minutes)
    /// </summary>
    public int NotificationThrottleSeconds { get; set; } = 300;

    /// <summary>
    /// Retry intervals (in seconds) for transient Firebase failures.
    /// Uses exponential backoff: [5, 15, 30, 60, 120]
    /// </summary>
    public int[] RetryIntervalsSeconds { get; set; } = { 5, 15, 30, 60, 120 };

    /// <summary>
    /// Maximum number of retry attempts for failed Firebase operations.
    /// Default: 5
    /// </summary>
    public int MaxRetryAttempts { get; set; } = 5;

    /// <summary>
    /// Enable verbose logging for Firebase operations (debugging).
    /// Default: false
    /// </summary>
    public bool VerboseLogging { get; set; } = false;

    /// <summary>
    /// Listen for acknowledgement changes from Firestore and sync back to alert engine.
    /// Default: true
    /// </summary>
    public bool EnableAcknowledgementSync { get; set; } = true;

    /// <summary>
    /// Firestore acknowledgement listener polling interval (milliseconds).
    /// Default: 5000 (5 seconds)
    /// </summary>
    public int AcknowledgementPollIntervalMs { get; set; } = 5000;

    /// <summary>
    /// Validates the configuration.
    /// </summary>
    public void Validate()
    {
        if (!Enabled)
            return;

        if (string.IsNullOrWhiteSpace(ProjectId))
            throw new InvalidOperationException("Firebase ProjectId is required when Firebase is enabled.");

        ResolveServiceAccountJsonPath();

        if (NotificationThrottleSeconds < 0)
            throw new InvalidOperationException("NotificationThrottleSeconds must be >= 0.");

        if (MaxRetryAttempts < 1)
            throw new InvalidOperationException("MaxRetryAttempts must be >= 1.");

        if (RetryIntervalsSeconds == null || RetryIntervalsSeconds.Length == 0)
            throw new InvalidOperationException("RetryIntervalsSeconds must contain at least one interval.");
    }

    public string ResolveServiceAccountJsonPath()
    {
        var attemptedPaths = new List<string>();

        foreach (var candidate in GetServiceAccountCandidates())
        {
            var resolvedPath = ResolveCandidatePath(candidate);
            if (string.IsNullOrWhiteSpace(resolvedPath))
                continue;

            attemptedPaths.Add(resolvedPath);
            if (File.Exists(resolvedPath))
                return resolvedPath;
        }

        var checkedPaths = attemptedPaths.Count > 0
            ? string.Join(", ", attemptedPaths.Distinct(StringComparer.OrdinalIgnoreCase))
            : "no candidate paths were configured";

        throw new FileNotFoundException(
            $"Firebase service account file not found. Checked: {checkedPaths}");
    }

    private IEnumerable<string?> GetServiceAccountCandidates()
    {
        yield return ServiceAccountJsonPath;
        yield return Environment.GetEnvironmentVariable(ServiceAccountEnvVar);
        yield return Environment.GetEnvironmentVariable(GoogleCredentialsEnvVar);

        var baseDirectory = AppContext.BaseDirectory;
        var currentDirectory = Directory.GetCurrentDirectory();

        yield return Path.Combine(baseDirectory, "firebase-service-account.json");
        yield return Path.Combine(baseDirectory, "config", "firebase-service-account.json");
        yield return Path.Combine(currentDirectory, "firebase-service-account.json");
        yield return Path.Combine(currentDirectory, "config", "firebase-service-account.json");
    }

    private static string? ResolveCandidatePath(string? candidate)
    {
        if (string.IsNullOrWhiteSpace(candidate))
            return null;

        var expandedPath = Environment.ExpandEnvironmentVariables(candidate.Trim());
        return Path.IsPathRooted(expandedPath)
            ? expandedPath
            : Path.GetFullPath(expandedPath, ServicePathResolver.BaseDirectory);
    }
}
