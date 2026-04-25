using System;
using System.Data.SQLite;
using System.ServiceProcess;
using System.Timers;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Cloud.Firestore;
using Google.Apis.Auth.OAuth2;
using Newtonsoft.Json;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using FirebaseAdmin.Auth;

namespace ScadaAlarmSyncService
{
    /// <summary>
    /// Windows Service for syncing SCADA alarms between SQLite and Firebase
    /// Handles real-time data push/fetch, cloud storage, and authentication
    /// </summary>
    public partial class ScadaAlarmSyncService : ServiceBase
    {
        private Timer _syncTimer;
        private FirestoreDb _firestoreDb;
        private FirebaseAuth _firebaseAuth;
        private readonly string _sqliteDbPath = @"C:\SCADA\alerts.db";
        private readonly string _serviceAccountPath = @"C:\SCADA\firebase-service-account.json";
        private readonly int _syncIntervalSeconds = 5;
        private DateTime _lastSyncTime = DateTime.MinValue;
        private HashSet<string> _syncedAlertIds = new HashSet<string>();
        
        public ScadaAlarmSyncService()
        {
            InitializeComponent();
            ServiceName = "ScadaAlarmSyncService";
        }

        protected override void OnStart(string[] args)
        {
            try
            {
                LogMessage("====================================");
                LogMessage("Starting SCADA Alarm Sync Service...");
                LogMessage($"Service Account: {_serviceAccountPath}");
                LogMessage($"SQLite Database: {_sqliteDbPath}");
                LogMessage($"Sync Interval: {_syncIntervalSeconds} seconds");
                
                InitializeFirebase();
                InitializeSQLiteDatabase();
                
                _syncTimer = new Timer(_syncIntervalSeconds * 1000);
                _syncTimer.Elapsed += OnSyncTimerElapsed;
                _syncTimer.AutoReset = true;
                _syncTimer.Start();
                
                LogMessage("✅ Service started successfully");
                LogMessage("====================================");
            }
            catch (Exception ex)
            {
                LogError($"❌ Critical error starting service: {ex.Message}");
                LogError($"Stack Trace: {ex.StackTrace}");
                throw;
            }
        }

        protected override void OnStop()
        {
            LogMessage("⏹ Stopping service...");
            _syncTimer?.Stop();
            _syncTimer?.Dispose();
            LogMessage("✅ Service stopped");
        }

        #region Firebase Initialization

        private void InitializeFirebase()
        {
            try
            {
                if (!File.Exists(_serviceAccountPath))
                {
                    throw new FileNotFoundException($"Service account file not found: {_serviceAccountPath}");
                }

                FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(_serviceAccountPath),
                    ProjectId = "scadadataserver"
                });
                
                _firestoreDb = FirestoreDb.Create("scadadataserver");
                _firebaseAuth = FirebaseAuth.DefaultInstance;
                
                LogMessage("✅ Firebase initialized successfully");
                LogMessage($"   - Project: scadadataserver");
                LogMessage($"   - Firestore: Connected");
                LogMessage($"   - Auth: Ready");
            }
            catch (Exception ex)
            {
                LogError($"❌ Firebase initialization failed: {ex.Message}");
                throw;
            }
        }

        private void InitializeSQLiteDatabase()
        {
            try
            {
                var dbDirectory = Path.GetDirectoryName(_sqliteDbPath);
                Directory.CreateDirectory(dbDirectory);

                if (!File.Exists(_sqliteDbPath))
                {
                    SQLiteConnection.CreateFile(_sqliteDbPath);
                    LogMessage($"✅ Created new SQLite database: {_sqliteDbPath}");
                    CreateDatabaseTables();
                }
                else
                {
                    LogMessage($"✅ SQLite database exists: {_sqliteDbPath}");
                    VerifyDatabaseSchema();
                }
            }
            catch (Exception ex)
            {
                LogError($"❌ SQLite initialization failed: {ex.Message}");
                throw;
            }
        }

        private void CreateDatabaseTables()
        {
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var createAlertsTable = @"
                    CREATE TABLE IF NOT EXISTS alerts (
                        id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        description TEXT,
                        severity TEXT NOT NULL,
                        location TEXT,
                        equipment TEXT,
                        timestamp INTEGER NOT NULL,
                        status TEXT NOT NULL,
                        acknowledged_by TEXT,
                        acknowledged_at INTEGER,
                        resolved_at INTEGER,
                        notes TEXT,
                        synced_to_cloud INTEGER DEFAULT 0,
                        last_cloud_sync INTEGER
                    )";
                
                var createSystemStatusTable = @"
                    CREATE TABLE IF NOT EXISTS system_status (
                        id TEXT PRIMARY KEY,
                        status TEXT NOT NULL,
                        active_alerts_count INTEGER DEFAULT 0,
                        critical_count INTEGER DEFAULT 0,
                        high_count INTEGER DEFAULT 0,
                        medium_count INTEGER DEFAULT 0,
                        low_count INTEGER DEFAULT 0,
                        last_update INTEGER NOT NULL,
                        synced_to_cloud INTEGER DEFAULT 0
                    )";
                
                var createSyncLogTable = @"
                    CREATE TABLE IF NOT EXISTS sync_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        sync_type TEXT NOT NULL,
                        direction TEXT NOT NULL,
                        records_count INTEGER,
                        status TEXT NOT NULL,
                        error_message TEXT,
                        timestamp INTEGER NOT NULL
                    )";
                
                using (var command = new SQLiteCommand(createAlertsTable, connection))
                {
                    command.ExecuteNonQuery();
                }
                
                using (var command = new SQLiteCommand(createSystemStatusTable, connection))
                {
                    command.ExecuteNonQuery();
                }
                
                using (var command = new SQLiteCommand(createSyncLogTable, connection))
                {
                    command.ExecuteNonQuery();
                }
                
                LogMessage("✅ Database tables created successfully");
            }
        }

        private void VerifyDatabaseSchema()
        {
            // Verify that required tables exist
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var checkTables = @"
                    SELECT name FROM sqlite_master 
                    WHERE type='table' AND name IN ('alerts', 'system_status', 'sync_log')";
                
                using (var command = new SQLiteCommand(checkTables, connection))
                using (var reader = command.ExecuteReader())
                {
                    var tables = new List<string>();
                    while (reader.Read())
                    {
                        tables.Add(reader.GetString(0));
                    }
                    
                    if (tables.Count < 3)
                    {
                        LogMessage("⚠ Missing tables, recreating schema...");
                        CreateDatabaseTables();
                    }
                    else
                    {
                        LogMessage($"✅ Database schema verified: {string.Join(", ", tables)}");
                    }
                }
            }
        }

        #endregion

        #region Sync Operations

        private async void OnSyncTimerElapsed(object sender, ElapsedEventArgs e)
        {
            try
            {
                var syncStart = DateTime.Now;
                LogMessage($"🔄 Starting sync cycle at {syncStart:yyyy-MM-dd HH:mm:ss}");
                
                // Bidirectional sync: Push local changes to cloud, fetch cloud updates
                await PushLocalAlertsToCloud();
                await FetchCloudAlertsToLocal();
                await SyncSystemStatus();
                await CheckAndSendNotifications();
                
                _lastSyncTime = DateTime.Now;
                var duration = (DateTime.Now - syncStart).TotalMilliseconds;
                LogMessage($"✅ Sync cycle completed in {duration:F0}ms");
            }
            catch (Exception ex)
            {
                LogError($"❌ Sync cycle error: {ex.Message}");
                RecordSyncError("full_sync", ex.Message);
            }
        }

        private async Task PushLocalAlertsToCloud()
        {
            try
            {
                var unsynced = GetUnsyncedLocalAlerts();
                if (unsynced.Count == 0)
                {
                    return;
                }
                
                LogMessage($"⬆ Pushing {unsynced.Count} local alerts to cloud...");
                
                var batch = _firestoreDb.StartBatch();
                
                foreach (var alert in unsynced)
                {
                    var alertId = alert["id"].ToString();
                    var firestoreAlert = NormalizeAlertForFirestore(alert);
                    var status = GetNormalizedString(firestoreAlert, "status", "active");
                    var isArchived = status == "approved" || status == "rejected" || status == "cleared";

                    if (isArchived)
                    {
                        batch.Set(_firestoreDb.Collection("alerts_history").Document(alertId), firestoreAlert);
                        batch.Delete(_firestoreDb.Collection("alerts_active").Document(alertId));
                    }
                    else
                    {
                        batch.Set(_firestoreDb.Collection("alerts_active").Document(alertId), firestoreAlert);
                    }

                    _syncedAlertIds.Add(alertId);
                }
                
                await batch.CommitAsync();
                MarkAlertsAsSynced(unsynced.Select(a => a["id"].ToString()).ToList());
                
                LogMessage($"✅ Pushed {unsynced.Count} alerts to cloud");
                RecordSyncSuccess("push_alerts", unsynced.Count);
            }
            catch (Exception ex)
            {
                LogError($"❌ Push alerts error: {ex.Message}");
                RecordSyncError("push_alerts", ex.Message);
            }
        }

        private async Task FetchCloudAlertsToLocal()
        {
            try
            {
                var documents = new Dictionary<string, DocumentSnapshot>();
                foreach (var collectionName in new[] { "alerts_active", "alerts_history" })
                {
                    var snapshot = await _firestoreDb.Collection(collectionName)
                        .OrderByDescending("lastUpdatedTime")
                        .Limit(100)
                        .GetSnapshotAsync();

                    foreach (var document in snapshot.Documents)
                    {
                        documents[document.Id] = document;
                    }
                }

                if (documents.Count == 0)
                {
                    return;
                }
                
                LogMessage($"⬇ Fetching {documents.Count} alerts from cloud...");
                
                var newAlerts = 0;
                using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
                {
                    connection.Open();
                    
                    foreach (var document in documents.Values)
                    {
                        var alertId = document.Id;
                        
                        if (_syncedAlertIds.Contains(alertId))
                        {
                            continue; // Skip alerts we just pushed
                        }
                        
                        var sqliteData = NormalizeAlertForSqlite(alertId, document.ToDictionary());

                        InsertOrUpdateAlert(connection, alertId, sqliteData);
                        newAlerts++;
                    }
                }
                
                if (newAlerts > 0)
                {
                    LogMessage($"✅ Fetched {newAlerts} new alerts from cloud");
                    RecordSyncSuccess("fetch_alerts", newAlerts);
                }
            }
            catch (Exception ex)
            {
                LogError($"❌ Fetch alerts error: {ex.Message}");
                RecordSyncError("fetch_alerts", ex.Message);
            }
        }

        private async Task SyncSystemStatus()
        {
            try
            {
                var status = CalculateSystemStatus();
                
                var statusRef = _firestoreDb.Collection("system_status").Document("current");
                await statusRef.SetAsync(status);
                
                SaveLocalSystemStatus(status);
            }
            catch (Exception ex)
            {
                LogError($"❌ System status sync error: {ex.Message}");
            }
        }

        private async Task CheckAndSendNotifications()
        {
            try
            {
                var criticalAlerts = GetCriticalUnnotifiedAlerts();
                
                foreach (var alert in criticalAlerts)
                {
                    await SendPushNotification(alert);
                }
            }
            catch (Exception ex)
            {
                LogError($"❌ Notification error: {ex.Message}");
            }
        }

        #endregion

        #region Database Operations

        private List<Dictionary<string, object>> GetUnsyncedLocalAlerts()
        {
            var alerts = new List<Dictionary<string, object>>();
            
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var query = @"
                    SELECT * FROM alerts 
                    WHERE synced_to_cloud = 0 
                    ORDER BY timestamp DESC 
                    LIMIT 50";
                
                using (var command = new SQLiteCommand(query, connection))
                using (var reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var alert = new Dictionary<string, object>
                        {
                            ["id"] = reader["id"].ToString(),
                            ["alert"] = reader["title"].ToString(),
                            ["detail"] = reader["description"].ToString(),
                            ["severity"] = reader["severity"].ToString(),
                            ["location"] = reader["location"].ToString(),
                            ["equipment"] = reader["equipment"].ToString(),
                            ["timestamp"] = Timestamp.FromDateTimeOffset(
                                DateTimeOffset.FromUnixTimeSeconds(Convert.ToInt64(reader["timestamp"]))),
                            ["status"] = reader["status"].ToString(),
                            ["acknowledgedBy"] = reader.IsDBNull(reader.GetOrdinal("acknowledged_by")) 
                                ? null : reader["acknowledged_by"].ToString(),
                            ["acknowledgedAt"] = reader.IsDBNull(reader.GetOrdinal("acknowledged_at")) 
                                ? null : Timestamp.FromDateTimeOffset(DateTimeOffset.FromUnixTimeSeconds(Convert.ToInt64(reader["acknowledged_at"]))),
                            ["acknowledged"] = !reader.IsDBNull(reader.GetOrdinal("acknowledged_at")),
                            ["notes"] = reader.IsDBNull(reader.GetOrdinal("notes")) 
                                ? "" : reader["notes"].ToString()
                        };
                        alerts.Add(alert);
                    }
                }
            }
            
            return alerts;
        }

        private void InsertOrUpdateAlert(SQLiteConnection connection, string alertId, Dictionary<string, object> data)
        {
            var checkQuery = "SELECT COUNT(*) FROM alerts WHERE id = @id";
            using (var checkCmd = new SQLiteCommand(checkQuery, connection))
            {
                checkCmd.Parameters.AddWithValue("@id", alertId);
                var exists = Convert.ToInt32(checkCmd.ExecuteScalar()) > 0;
                
                if (exists)
                {
                    UpdateExistingAlert(connection, alertId, data);
                }
                else
                {
                    InsertNewAlert(connection, alertId, data);
                }
            }
        }

        private void InsertNewAlert(SQLiteConnection connection, string alertId, Dictionary<string, object> data)
        {
            var insertQuery = @"
                INSERT INTO alerts (
                    id, title, description, severity, location, equipment, 
                    timestamp, status, acknowledged_by, acknowledged_at, resolved_at, notes, 
                    synced_to_cloud, last_cloud_sync
                ) VALUES (
                    @id, @title, @description, @severity, @location, @equipment,
                    @timestamp, @status, @acknowledged_by, @acknowledged_at, @resolved_at, @notes,
                    1, @last_cloud_sync
                )";
            
            using (var cmd = new SQLiteCommand(insertQuery, connection))
            {
                cmd.Parameters.AddWithValue("@id", alertId);
                cmd.Parameters.AddWithValue("@title", GetValue(data, "title", ""));
                cmd.Parameters.AddWithValue("@description", GetValue(data, "description", ""));
                cmd.Parameters.AddWithValue("@severity", GetValue(data, "severity", "medium"));
                cmd.Parameters.AddWithValue("@location", GetValue(data, "location", ""));
                cmd.Parameters.AddWithValue("@equipment", GetValue(data, "equipment", ""));
                cmd.Parameters.AddWithValue("@timestamp", GetTimestampValue(data, "timestamp"));
                cmd.Parameters.AddWithValue("@status", GetValue(data, "status", "active"));
                cmd.Parameters.AddWithValue("@acknowledged_by", GetValue(data, "acknowledged_by", DBNull.Value));
                cmd.Parameters.AddWithValue("@acknowledged_at", GetValue(data, "acknowledged_at", DBNull.Value));
                cmd.Parameters.AddWithValue("@resolved_at", GetValue(data, "resolved_at", DBNull.Value));
                cmd.Parameters.AddWithValue("@notes", GetValue(data, "notes", ""));
                cmd.Parameters.AddWithValue("@last_cloud_sync", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                cmd.ExecuteNonQuery();
            }
        }

        private void UpdateExistingAlert(SQLiteConnection connection, string alertId, Dictionary<string, object> data)
        {
            var updateQuery = @"
                UPDATE alerts SET
                    status = @status,
                    acknowledged_by = @acknowledged_by,
                    acknowledged_at = @acknowledged_at,
                    resolved_at = @resolved_at,
                    notes = @notes,
                    synced_to_cloud = 1,
                    last_cloud_sync = @last_cloud_sync
                WHERE id = @id";
            
            using (var cmd = new SQLiteCommand(updateQuery, connection))
            {
                cmd.Parameters.AddWithValue("@id", alertId);
                cmd.Parameters.AddWithValue("@status", GetValue(data, "status", "active"));
                cmd.Parameters.AddWithValue("@acknowledged_by", GetValue(data, "acknowledged_by", DBNull.Value));
                cmd.Parameters.AddWithValue("@acknowledged_at", GetValue(data, "acknowledged_at", DBNull.Value));
                cmd.Parameters.AddWithValue("@resolved_at", GetValue(data, "resolved_at", DBNull.Value));
                cmd.Parameters.AddWithValue("@notes", GetValue(data, "notes", ""));
                cmd.Parameters.AddWithValue("@last_cloud_sync", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                cmd.ExecuteNonQuery();
            }
        }

        private void MarkAlertsAsSynced(List<string> alertIds)
        {
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var query = @"
                    UPDATE alerts 
                    SET synced_to_cloud = 1, last_cloud_sync = @sync_time 
                    WHERE id IN ({0})";
                
                var placeholders = string.Join(",", alertIds.Select((_, i) => $"@id{i}"));
                query = string.Format(query, placeholders);
                
                using (var command = new SQLiteCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@sync_time", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                    for (int i = 0; i < alertIds.Count; i++)
                    {
                        command.Parameters.AddWithValue($"@id{i}", alertIds[i]);
                    }
                    command.ExecuteNonQuery();
                }
            }
        }

        private Dictionary<string, object> CalculateSystemStatus()
        {
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var query = @"
                    SELECT 
                        COUNT(*) as total,
                        SUM(CASE WHEN severity = 'critical' THEN 1 ELSE 0 END) as critical,
                        SUM(CASE WHEN severity = 'high' THEN 1 ELSE 0 END) as high,
                        SUM(CASE WHEN severity = 'medium' THEN 1 ELSE 0 END) as medium,
                        SUM(CASE WHEN severity = 'low' THEN 1 ELSE 0 END) as low
                    FROM alerts 
                    WHERE status IN ('active', 'acknowledged')";
                
                using (var command = new SQLiteCommand(query, connection))
                using (var reader = command.ExecuteReader())
                {
                    if (reader.Read())
                    {
                        var total = Convert.ToInt32(reader["total"]);
                        var critical = Convert.ToInt32(reader["critical"]);
                        
                        return new Dictionary<string, object>
                        {
                            ["status"] = critical > 0 ? "critical" : (total > 0 ? "warning" : "normal"),
                            ["active_alerts_count"] = total,
                            ["critical_count"] = critical,
                            ["high_count"] = Convert.ToInt32(reader["high"]),
                            ["medium_count"] = Convert.ToInt32(reader["medium"]),
                            ["low_count"] = Convert.ToInt32(reader["low"]),
                            ["last_update"] = Timestamp.FromDateTime(DateTime.UtcNow),
                            ["timestamp"] = Timestamp.FromDateTime(DateTime.UtcNow)
                        };
                    }
                }
            }
            
            return new Dictionary<string, object>
            {
                ["status"] = "normal",
                ["active_alerts_count"] = 0,
                ["last_update"] = Timestamp.FromDateTime(DateTime.UtcNow)
            };
        }

        private void SaveLocalSystemStatus(Dictionary<string, object> status)
        {
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var query = @"
                    INSERT OR REPLACE INTO system_status (
                        id, status, active_alerts_count, critical_count, high_count, 
                        medium_count, low_count, last_update, synced_to_cloud
                    ) VALUES (
                        'current', @status, @active_count, @critical, @high, 
                        @medium, @low, @last_update, 1
                    )";
                
                using (var command = new SQLiteCommand(query, connection))
                {
                    command.Parameters.AddWithValue("@status", status["status"]);
                    command.Parameters.AddWithValue("@active_count", status["active_alerts_count"]);
                    command.Parameters.AddWithValue("@critical", GetValue(status, "critical_count", 0));
                    command.Parameters.AddWithValue("@high", GetValue(status, "high_count", 0));
                    command.Parameters.AddWithValue("@medium", GetValue(status, "medium_count", 0));
                    command.Parameters.AddWithValue("@low", GetValue(status, "low_count", 0));
                    command.Parameters.AddWithValue("@last_update", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                    command.ExecuteNonQuery();
                }
            }
        }

        private List<Dictionary<string, object>> GetCriticalUnnotifiedAlerts()
        {
            var alerts = new List<Dictionary<string, object>>();
            
            using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
            {
                connection.Open();
                
                var query = @"
                    SELECT * FROM alerts 
                    WHERE severity = 'critical' 
                    AND status = 'active' 
                    AND acknowledged_by IS NULL
                    LIMIT 10";
                
                using (var command = new SQLiteCommand(query, connection))
                using (var reader = command.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        alerts.Add(new Dictionary<string, object>
                        {
                            ["id"] = reader["id"].ToString(),
                            ["alert"] = reader["title"].ToString(),
                            ["detail"] = reader["description"].ToString(),
                            ["location"] = reader["location"].ToString()
                        });
                    }
                }
            }
            
            return alerts;
        }

        #endregion

        #region Push Notifications

        private async Task SendPushNotification(Dictionary<string, object> alert)
        {
            try
            {
                var message = new Message
                {
                    Topic = "critical_alerts",
                    Notification = new Notification
                    {
                        Title = $"🚨 CRITICAL: {alert["alert"]}",
                        Body = alert["detail"].ToString()
                    },
                    Data = new Dictionary<string, string>
                    {
                        ["alert_id"] = alert["id"].ToString(),
                        ["severity"] = "critical",
                        ["location"] = alert["location"].ToString()
                    },
                    Android = new AndroidConfig
                    {
                        Priority = Priority.High,
                        Notification = new AndroidNotification
                        {
                            Sound = "default",
                            ChannelId = "critical_alerts"
                        }
                    }
                };
                
                await FirebaseMessaging.DefaultInstance.SendAsync(message);
                LogMessage($"📱 Push notification sent for alert: {alert["id"]}");
            }
            catch (Exception ex)
            {
                LogError($"❌ Push notification failed: {ex.Message}");
            }
        }

        #endregion

        #region Logging and Utilities

        private void RecordSyncSuccess(string syncType, int recordsCount)
        {
            RecordSyncLog(syncType, "push", recordsCount, "success", null);
        }

        private void RecordSyncError(string syncType, string errorMessage)
        {
            RecordSyncLog(syncType, "push", 0, "error", errorMessage);
        }

        private void RecordSyncLog(string syncType, string direction, int recordsCount, string status, string errorMessage)
        {
            try
            {
                using (var connection = new SQLiteConnection($"Data Source={_sqliteDbPath};Version=3;"))
                {
                    connection.Open();
                    
                    var query = @"
                        INSERT INTO sync_log (sync_type, direction, records_count, status, error_message, timestamp)
                        VALUES (@sync_type, @direction, @records_count, @status, @error_message, @timestamp)";
                    
                    using (var command = new SQLiteCommand(query, connection))
                    {
                        command.Parameters.AddWithValue("@sync_type", syncType);
                        command.Parameters.AddWithValue("@direction", direction);
                        command.Parameters.AddWithValue("@records_count", recordsCount);
                        command.Parameters.AddWithValue("@status", status);
                        command.Parameters.AddWithValue("@error_message", errorMessage ?? (object)DBNull.Value);
                        command.Parameters.AddWithValue("@timestamp", DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                        command.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                LogError($"Failed to record sync log: {ex.Message}");
            }
        }

        private object GetValue(Dictionary<string, object> dict, string key, object defaultValue)
        {
            return dict.ContainsKey(key) && dict[key] != null ? dict[key] : defaultValue;
        }

        private Dictionary<string, object> NormalizeAlertForFirestore(Dictionary<string, object> localAlert)
        {
            var alertId = GetNormalizedString(localAlert, "id", Guid.NewGuid().ToString("N"));
            var title = GetNormalizedString(localAlert, "title", GetNormalizedString(localAlert, "alert", "SCADA Alarm"));
            var description = GetNormalizedString(localAlert, "description", GetNormalizedString(localAlert, "detail", string.Empty));
            var severity = GetNormalizedString(localAlert, "severity", "warning").ToLowerInvariant();
            var location = GetNormalizedString(localAlert, "location", string.Empty);
            var equipment = GetNormalizedString(localAlert, "equipment", string.Empty);
            var raisedAt = Timestamp.FromDateTimeOffset(DateTimeOffset.FromUnixTimeSeconds(GetTimestampValue(localAlert, "timestamp")));
            var acknowledgedAt = GetOptionalTimestamp(localAlert, "acknowledgedAt", "acknowledged_at");
            var resolvedAt = GetOptionalTimestamp(localAlert, "clearedAt", "clearedTime", "resolved_at");
            var status = GetNormalizedString(localAlert, "status", "active");
            var isAcknowledged = acknowledgedAt != null || GetOptionalBool(localAlert, "isAcknowledged", "acknowledged");
            var now = Timestamp.FromDateTime(DateTime.UtcNow);

            return new Dictionary<string, object>
            {
                ["id"] = alertId,
                ["alertId"] = alertId,
                ["alert"] = title,
                ["name"] = title,
                ["detail"] = description,
                ["description"] = description,
                ["severity"] = severity,
                ["source"] = equipment,
                ["location"] = location,
                ["equipment"] = equipment,
                ["tagName"] = equipment,
                ["nodeId"] = equipment,
                ["timestamp"] = raisedAt,
                ["raisedAt"] = raisedAt,
                ["status"] = status,
                ["approvalStatus"] = status switch
                {
                    "approved" => "approved",
                    "rejected" => "rejected",
                    "cleared" => "approved",
                    _ => "pending"
                },
                ["isActive"] = status == "active" || status == "acknowledged",
                ["isAcknowledged"] = isAcknowledged,
                ["acknowledged"] = isAcknowledged,
                ["acknowledgedBy"] = GetOptionalString(localAlert, "acknowledgedBy", "acknowledged_by"),
                ["acknowledged_by"] = GetOptionalString(localAlert, "acknowledgedBy", "acknowledged_by"),
                ["acknowledgedAt"] = acknowledgedAt,
                ["acknowledged_at"] = acknowledgedAt,
                ["acknowledgedComment"] = GetOptionalString(localAlert, "acknowledgedComment", "notes"),
                ["acknowledgement_detail"] = GetOptionalString(localAlert, "acknowledgedComment", "notes"),
                ["currentValue"] = 0.0,
                ["triggerValue"] = 0.0,
                ["threshold"] = 0.0,
                ["condition"] = "sqlite_sync",
                ["clearedAt"] = resolvedAt,
                ["clearedTime"] = resolvedAt,
                ["notes"] = GetNormalizedString(localAlert, "notes", string.Empty),
                ["created_at"] = raisedAt,
                ["updated_at"] = now,
                ["lastUpdatedTime"] = now
            };
        }

        private Dictionary<string, object> NormalizeAlertForSqlite(string alertId, Dictionary<string, object> firestoreData)
        {
            var acknowledgedAt = GetOptionalTimestamp(firestoreData, "acknowledgedAt", "acknowledged_at");
            var resolvedAt = GetOptionalTimestamp(firestoreData, "clearedAt", "clearedTime", "resolved_at");

            return new Dictionary<string, object>
            {
                ["title"] = GetNormalizedString(firestoreData, "name", GetNormalizedString(firestoreData, "alert", "SCADA Alarm")),
                ["description"] = GetNormalizedString(firestoreData, "description", GetNormalizedString(firestoreData, "detail", string.Empty)),
                ["severity"] = GetNormalizedString(firestoreData, "severity", "warning"),
                ["location"] = GetNormalizedString(firestoreData, "location", string.Empty),
                ["equipment"] = GetNormalizedString(firestoreData, "equipment", string.Empty),
                ["timestamp"] = GetTimestampValue(firestoreData, "raisedAt"),
                ["status"] = GetNormalizedString(firestoreData, "status", "active"),
                ["acknowledged_by"] = GetOptionalString(firestoreData, "acknowledgedBy", "acknowledged_by"),
                ["acknowledged_at"] = acknowledgedAt != null
                    ? acknowledgedAt.Value.ToDateTimeOffset().ToUnixTimeSeconds()
                    : (object)DBNull.Value,
                ["resolved_at"] = resolvedAt != null
                    ? resolvedAt.Value.ToDateTimeOffset().ToUnixTimeSeconds()
                    : (object)DBNull.Value,
                ["notes"] = GetNormalizedString(firestoreData, "notes", GetNormalizedString(firestoreData, "acknowledgedComment", string.Empty))
            };
        }

        private string GetNormalizedString(Dictionary<string, object> dict, string key, string defaultValue)
        {
            return dict.ContainsKey(key) && dict[key] != null
                ? dict[key].ToString()
                : defaultValue;
        }

        private string GetOptionalString(Dictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (dict.ContainsKey(key) && dict[key] != null)
                {
                    return dict[key].ToString();
                }
            }

            return null;
        }

        private bool GetOptionalBool(Dictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.ContainsKey(key) || dict[key] == null)
                {
                    continue;
                }

                if (dict[key] is bool boolValue)
                {
                    return boolValue;
                }

                if (bool.TryParse(dict[key].ToString(), out var parsed))
                {
                    return parsed;
                }
            }

            return false;
        }

        private Timestamp? GetOptionalTimestamp(Dictionary<string, object> dict, params string[] keys)
        {
            foreach (var key in keys)
            {
                if (!dict.ContainsKey(key) || dict[key] == null)
                {
                    continue;
                }

                if (dict[key] is Timestamp timestamp)
                {
                    return timestamp;
                }

                if (dict[key] is long longValue)
                {
                    return Timestamp.FromDateTimeOffset(DateTimeOffset.FromUnixTimeSeconds(longValue));
                }

                if (dict[key] is int intValue)
                {
                    return Timestamp.FromDateTimeOffset(DateTimeOffset.FromUnixTimeSeconds(intValue));
                }
            }

            return null;
        }

        private long GetTimestampValue(Dictionary<string, object> dict, string key)
        {
            if (dict.ContainsKey(key) && dict[key] != null)
            {
                if (dict[key] is Timestamp ts)
                {
                    return ts.ToDateTimeOffset().ToUnixTimeSeconds();
                }
                if (dict[key] is long l)
                {
                    return l;
                }
                if (dict[key] is int i)
                {
                    return i;
                }
            }
            return DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        }

        private void LogMessage(string message)
        {
            var logPath = @"C:\SCADA\Logs\sync_service.log";
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                var logEntry = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [INFO] {message}\n";
                File.AppendAllText(logPath, logEntry);
                Console.WriteLine(logEntry.TrimEnd());
            }
            catch
            {
                // Fail silently to avoid cascading errors
            }
        }

        private void LogError(string message)
        {
            var logPath = @"C:\SCADA\Logs\sync_service.log";
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(logPath));
                var logEntry = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} [ERROR] {message}\n";
                File.AppendAllText(logPath, logEntry);
                Console.Error.WriteLine(logEntry.TrimEnd());
            }
            catch
            {
                // Fail silently
            }
        }

        #endregion
    }

    #region Service Installer Component

    partial class ScadaAlarmSyncService
    {
        private System.ComponentModel.IContainer components = null;

        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        private void InitializeComponent()
        {
            components = new System.ComponentModel.Container();
            this.ServiceName = "ScadaAlarmSyncService";
        }
    }

    #endregion
}
