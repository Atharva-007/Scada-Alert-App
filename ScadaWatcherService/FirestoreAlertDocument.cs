using Google.Cloud.Firestore;

namespace ScadaWatcherService;

/// <summary>
/// Firestore document model for alert synchronization.
/// Maps to documents in Firestore collections: alerts_active, alerts_history.
/// </summary>
[FirestoreData]
public class FirestoreAlertDocument
{
    [FirestoreProperty("id")]
    public string Id { get; set; } = string.Empty;

    /// <summary>
    /// Unique alert identifier (RuleId).
    /// Serves as the Firestore document ID.
    /// </summary>
    [FirestoreProperty("alertId")]
    public string AlertId { get; set; } = string.Empty;

    /// <summary>
    /// OPC UA Node ID that triggered this alert.
    /// </summary>
    [FirestoreProperty("nodeId")]
    public string NodeId { get; set; } = string.Empty;

    /// <summary>
    /// Alert rule description.
    /// </summary>
    [FirestoreProperty("detail")]
    public string Description { get; set; } = string.Empty;

    [FirestoreProperty("description")]
    public string DescriptionText { get; set; } = string.Empty;

    /// <summary>
    /// Alert severity: "Info", "Warning", "Critical"
    /// </summary>
    [FirestoreProperty("severity")]
    public string Severity { get; set; } = string.Empty;

    /// <summary>
    /// Alert type: "HighThreshold", "LowThreshold", "RateOfChange", etc.
    /// </summary>
    [FirestoreProperty("alertType")]
    public string AlertType { get; set; } = string.Empty;

    /// <summary>
    /// Current alert state: "Inactive", "Active", "Acknowledged", "Cleared"
    /// </summary>
    [FirestoreProperty("status")]
    public string CurrentState { get; set; } = string.Empty;

    /// <summary>
    /// Formatted alert message.
    /// </summary>
    [FirestoreProperty("alert")]
    public string Message { get; set; } = string.Empty;

    [FirestoreProperty("name")]
    public string Name { get; set; } = string.Empty;

    [FirestoreProperty("source")]
    public string Source { get; set; } = string.Empty;

    [FirestoreProperty("tagName")]
    public string TagName { get; set; } = string.Empty;

    /// <summary>
    /// Whether the alert has been acknowledged.
    /// </summary>
    [FirestoreProperty("acknowledged")]
    public bool Acknowledged { get; set; } = false;

    /// <summary>
    /// Value that triggered the alert (numeric, boolean, or string).
    /// Stored as object to handle multiple types.
    /// </summary>
    [FirestoreProperty("triggerValue")]
    public object? TriggerValue { get; set; }

    [FirestoreProperty("currentValue")]
    public double? CurrentValue { get; set; }

    /// <summary>
    /// Threshold value (for threshold-based alerts).
    /// </summary>
    [FirestoreProperty("threshold")]
    public double? Threshold { get; set; }

    /// <summary>
    /// Timestamp when alert was first raised (UTC).
    /// </summary>
    [FirestoreProperty("timestamp")]
    public Timestamp RaisedTime { get; set; }

    [FirestoreProperty("raisedAt")]
    public Timestamp RaisedAt { get; set; }

    /// <summary>
    /// Timestamp when alert was acknowledged (UTC, nullable).
    /// </summary>
    [FirestoreProperty("acknowledgedAt")]
    public Timestamp? AcknowledgedTime { get; set; }

    /// <summary>
    /// Timestamp when alert was cleared (UTC, nullable).
    /// </summary>
    [FirestoreProperty("clearedTime")]
    public Timestamp? ClearedTime { get; set; }

    /// <summary>
    /// Timestamp of the last update to this document (UTC).
    /// </summary>
    [FirestoreProperty("lastUpdatedTime")]
    public Timestamp LastUpdatedTime { get; set; }

    [FirestoreProperty("created_at")]
    public Timestamp CreatedAt { get; set; }

    [FirestoreProperty("updated_at")]
    public Timestamp UpdatedAt { get; set; }

    /// <summary>
    /// Number of times this alert has escalated.
    /// </summary>
    [FirestoreProperty("escalationCount")]
    public int EscalationCount { get; set; } = 0;

    /// <summary>
    /// Whether this alert has been escalated.
    /// </summary>
    [FirestoreProperty("isEscalated")]
    public bool IsEscalated { get; set; } = false;

    /// <summary>
    /// User ID or device ID that acknowledged this alert (optional).
    /// </summary>
    [FirestoreProperty("acknowledgedBy")]
    public string? AcknowledgedBy { get; set; }

    /// <summary>
    /// Detailed message provided during acknowledgement.
    /// </summary>
    [FirestoreProperty("acknowledgement_detail")]
    public string? AcknowledgementDetail { get; set; }

    [FirestoreProperty("acknowledgedComment")]
    public string? AcknowledgedComment { get; set; }

    /// <summary>
    /// Active duration in seconds (for cleared alerts).
    /// </summary>
    [FirestoreProperty("activeDurationSeconds")]
    public long? ActiveDurationSeconds { get; set; }

    [FirestoreProperty("isActive")]
    public bool IsActive { get; set; } = true;

    [FirestoreProperty("isAcknowledged")]
    public bool IsAcknowledged { get; set; } = false;

    [FirestoreProperty("condition")]
    public string Condition { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when last notification was sent (for throttling).
    /// </summary>
    [FirestoreProperty("lastNotificationTime")]
    public Timestamp? LastNotificationTime { get; set; }

    /// <summary>
    /// Count of notifications sent for this alert.
    /// </summary>
    [FirestoreProperty("notificationCount")]
    public int NotificationCount { get; set; } = 0;

    /// <summary>
    /// Approval status: "pending", "approved", "rejected"
    /// </summary>
    [FirestoreProperty("approvalStatus")]
    public string ApprovalStatus { get; set; } = "pending";

    /// <summary>
    /// User who approved the alert.
    /// </summary>
    [FirestoreProperty("approvedBy")]
    public string? ApprovedBy { get; set; }

    /// <summary>
    /// Timestamp when the alert was approved.
    /// </summary>
    [FirestoreProperty("approvedAt")]
    public Timestamp? ApprovedAt { get; set; }

    /// <summary>
    /// User who rejected the alert.
    /// </summary>
    [FirestoreProperty("rejectedBy")]
    public string? RejectedBy { get; set; }

    /// <summary>
    /// Timestamp when the alert was rejected.
    /// </summary>
    [FirestoreProperty("rejectedAt")]
    public Timestamp? RejectedAt { get; set; }

    /// <summary>
    /// Reason for rejection.
    /// </summary>
    [FirestoreProperty("rejectionReason")]
    public string? RejectionReason { get; set; }

    [FirestoreProperty("clearedAt")]
    public Timestamp? ClearedAt { get; set; }

    /// <summary>
    /// Creates a Firestore document from an ActiveAlert.
    /// </summary>
    public static FirestoreAlertDocument FromActiveAlert(ActiveAlert alert)
    {
        var raisedTimestamp = Timestamp.FromDateTime(alert.FirstRaisedTime.ToUniversalTime());
        var lastUpdatedTimestamp = Timestamp.FromDateTime(DateTime.UtcNow);
        var currentValue = TryConvertToDouble(alert.TriggerValue);

        return new FirestoreAlertDocument
        {
            Id = alert.Rule.RuleId,
            AlertId = alert.Rule.RuleId,
            NodeId = alert.Rule.NodeId,
            Description = alert.Rule.Description,
            DescriptionText = alert.Rule.Description,
            Severity = alert.Rule.Severity.ToString().ToLower(),
            AlertType = alert.Rule.AlertType.ToString(),
            CurrentState = alert.State.ToString().ToLower(),
            Message = alert.Message,
            Name = alert.Message,
            Source = alert.Rule.NodeId,
            TagName = alert.Rule.NodeId,
            TriggerValue = alert.TriggerValue,
            CurrentValue = currentValue,
            Threshold = alert.Rule.Threshold,
            RaisedTime = raisedTimestamp,
            RaisedAt = raisedTimestamp,
            AcknowledgedTime = alert.AcknowledgedTime.HasValue 
                ? Timestamp.FromDateTime(alert.AcknowledgedTime.Value.ToUniversalTime()) 
                : null,
            AcknowledgedBy = alert.AcknowledgedBy,
            AcknowledgementDetail = alert.AcknowledgementDetail,
            AcknowledgedComment = alert.AcknowledgementDetail,
            Acknowledged = alert.AcknowledgedTime.HasValue,
            ClearedTime = alert.ClearedTime.HasValue 
                ? Timestamp.FromDateTime(alert.ClearedTime.Value.ToUniversalTime()) 
                : null,
            ClearedAt = alert.ClearedTime.HasValue
                ? Timestamp.FromDateTime(alert.ClearedTime.Value.ToUniversalTime())
                : null,
            LastUpdatedTime = lastUpdatedTimestamp,
            CreatedAt = raisedTimestamp,
            UpdatedAt = lastUpdatedTimestamp,
            EscalationCount = alert.IsEscalated ? 1 : 0,
            IsEscalated = alert.IsEscalated,
            ActiveDurationSeconds = alert.ClearedTime.HasValue 
                ? (long)alert.ActiveDuration.TotalSeconds 
                : null,
            IsActive = alert.State != AlertState.Cleared &&
                alert.ApprovalStatus != "approved" &&
                alert.ApprovalStatus != "rejected",
            IsAcknowledged = alert.AcknowledgedTime.HasValue,
            Condition = alert.Rule.AlertType.ToString().ToLowerInvariant(),
            ApprovalStatus = alert.ApprovalStatus,
            ApprovedBy = alert.ApprovedBy,
            ApprovedAt = alert.ApprovedAt.HasValue ? Timestamp.FromDateTime(alert.ApprovedAt.Value.ToUniversalTime()) : null,
            RejectedBy = alert.RejectedBy,
            RejectedAt = alert.RejectedAt.HasValue ? Timestamp.FromDateTime(alert.RejectedAt.Value.ToUniversalTime()) : null,
            RejectionReason = alert.RejectionReason
        };
    }

    private static double? TryConvertToDouble(object? value)
    {
        if (value == null)
        {
            return null;
        }

        return value switch
        {
            double d => d,
            float f => f,
            decimal m => (double)m,
            int i => i,
            long l => l,
            short s => s,
            byte b => b,
            _ when double.TryParse(value.ToString(), out var parsed) => parsed,
            _ => null
        };
    }
}

/// <summary>
/// Firestore document model for alert event audit trail.
/// Maps to documents in the "alert_events" collection.
/// </summary>
[FirestoreData]
public class FirestoreAlertEvent
{
    /// <summary>
    /// Event ID (auto-generated).
    /// </summary>
    [FirestoreProperty("eventId")]
    public string EventId { get; set; } = Guid.NewGuid().ToString();

    /// <summary>
    /// Alert ID (RuleId) that this event belongs to.
    /// </summary>
    [FirestoreProperty("alertId")]
    public string AlertId { get; set; } = string.Empty;

    /// <summary>
    /// Event type: "Raised", "Cleared", "Escalated", "Acknowledged"
    /// </summary>
    [FirestoreProperty("eventType")]
    public string EventType { get; set; } = string.Empty;

    /// <summary>
    /// Timestamp when the event occurred (UTC).
    /// </summary>
    [FirestoreProperty("timestamp")]
    public Timestamp Timestamp { get; set; }

    /// <summary>
    /// Alert severity at the time of the event.
    /// </summary>
    [FirestoreProperty("severity")]
    public string Severity { get; set; } = string.Empty;

    /// <summary>
    /// Event message or description.
    /// </summary>
    [FirestoreProperty("message")]
    public string Message { get; set; } = string.Empty;

    /// <summary>
    /// Value at the time of the event.
    /// </summary>
    [FirestoreProperty("value")]
    public object? Value { get; set; }

    /// <summary>
    /// User or system that triggered this event (optional).
    /// </summary>
    [FirestoreProperty("triggeredBy")]
    public string? TriggeredBy { get; set; }
}
