# OPC UA EXTENSION - Technical Documentation

## OVERVIEW

Your SCADA Watcher Service has been extended with industrial-grade OPC UA data acquisition capabilities. The OPC UA client runs as a completely separate internal service that **does not interfere** with the existing Flutter process watchdog.

---

## ARCHITECTURE

### **Separation of Concerns**

```
Worker Service
├── Flutter Process Supervision (existing)
│   ├── Watchdog loop (unmodified)
│   ├── Auto-restart with exponential backoff
│   └── Graceful shutdown
│
└── OPC UA Client Service (new)
    ├── Independent lifecycle
    ├── Subscription-based data collection
    ├── Automatic reconnection
    └── Event-driven data processing
```

**Key Design Principles:**
- OPC UA runs in parallel, not sequentially
- OPC UA failures do NOT crash the service
- OPC UA failures do NOT affect Flutter supervision
- Clean integration via dependency injection
- Can be disabled via configuration

---

## FILES ADDED

### **1. OpcUaConfiguration.cs**
Strongly-typed configuration model bound to `appsettings.json`.

**Key Properties:**
- `Enabled`: Master on/off switch
- `EndpointUrl`: OPC UA server address
- `SecurityMode`: None/Sign/SignAndEncrypt
- `SecurityPolicy`: Security policy selection
- `AuthenticationMode`: Anonymous or UsernamePassword
- `Nodes`: List of nodes to monitor with deadband filters

### **2. OpcUaDataValue.cs**
Normalized data model for received OPC UA values.

**Features:**
- Type-agnostic value storage
- Quality/status code tracking
- Source and received timestamps
- Helper methods for type conversion
- Safe null handling

### **3. OpcUaClientService.cs** (890 lines)
Production-grade OPC UA client implementation.

**Core Features:**
- READ-ONLY client (no writes for safety)
- Subscription-based data change notifications
- Automatic reconnection with exponential backoff
- Certificate validation and security policy support
- Comprehensive exception handling
- Serilog integration
- Event-driven architecture

**Public Events:**
- `DataReceived`: Raised when new data arrives
- `ConnectionStateChanged`: Connection status updates

---

## FILES MODIFIED

### **Worker.cs**
**Changes:**
- Added `OpcUaClientService?` field (nullable, optional)
- Added OPC UA startup in `ExecuteAsync()`
- Added OPC UA shutdown in `StopAsync()`
- Added event handlers: `OpcUaClient_DataReceived()`, `OpcUaClient_ConnectionStateChanged()`
- **Watchdog loop: UNCHANGED** (zero modifications to existing logic)

### **Program.cs**
**Changes:**
- Added `OpcUaConfiguration` binding
- Registered `OpcUaClientService` as singleton
- **Existing services: UNCHANGED**

### **appsettings.json**
**Changes:**
- Added complete `OpcUa` section with production defaults
- `Enabled: false` by default (must be explicitly enabled)

### **appsettings.Development.json**
**Changes:**
- Added `OpcUa` section with testing-friendly defaults
- `Enabled: true` with local test server settings

---

## CONFIGURATION GUIDE

### **Production Configuration (appsettings.json)**

```json
{
  "OpcUa": {
    "Enabled": true,
    "EndpointUrl": "opc.tcp://192.168.1.100:4840/UA/Server",
    "SecurityMode": "SignAndEncrypt",
    "SecurityPolicy": "Basic256Sha256",
    "AuthenticationMode": "UsernamePassword",
    "Username": "scada_user",
    "Password": "secure_password",
    "SessionTimeoutMs": 60000,
    "KeepAliveIntervalMs": 10000,
    "ReconnectDelaySeconds": 10,
    "MaxReconnectDelaySeconds": 300,
    "PublishingIntervalMs": 1000,
    "SamplingIntervalMs": 1000,
    "QueueSize": 10,
    "AcceptUntrustedCertificates": false,
    "AutoAcceptCertificates": false,
    "Nodes": [
      {
        "NodeId": "ns=2;s=Plant.Reactor.Temperature",
        "DisplayName": "Reactor Temperature",
        "SamplingIntervalMs": 500,
        "DeadbandType": "Absolute",
        "DeadbandValue": 0.5
      },
      {
        "NodeId": "ns=2;s=Plant.Reactor.Pressure",
        "DisplayName": "Reactor Pressure",
        "SamplingIntervalMs": 500,
        "DeadbandType": "Percent",
        "DeadbandValue": 1.0
      },
      {
        "NodeId": "ns=2;s=Plant.Status",
        "DisplayName": "Plant Status",
        "DeadbandType": "None"
      }
    ]
  }
}
```

### **Testing Configuration**

```json
{
  "OpcUa": {
    "Enabled": true,
    "EndpointUrl": "opc.tcp://localhost:53530/OPCUA/SimulationServer",
    "SecurityMode": "None",
    "SecurityPolicy": "None",
    "AuthenticationMode": "Anonymous",
    "AcceptUntrustedCertificates": true,
    "AutoAcceptCertificates": true,
    "Nodes": [
      {
        "NodeId": "ns=3;i=1001",
        "DisplayName": "Counter"
      }
    ]
  }
}
```

---

## CONFIGURATION PARAMETERS

### **Connection Settings**

| Parameter | Description | Production Value | Test Value |
|-----------|-------------|------------------|------------|
| `Enabled` | Enable OPC UA client | `true` | `true` |
| `EndpointUrl` | Server address | `opc.tcp://ip:port/path` | `opc.tcp://localhost:...` |
| `SecurityMode` | Security level | `SignAndEncrypt` | `None` |
| `SecurityPolicy` | Policy algorithm | `Basic256Sha256` | `None` |
| `AuthenticationMode` | Auth type | `UsernamePassword` | `Anonymous` |
| `Username` | Login username | `scada_user` | `""` |
| `Password` | Login password | Use env variable! | `""` |

### **Session Settings**

| Parameter | Description | Recommended |
|-----------|-------------|-------------|
| `SessionTimeoutMs` | Session timeout | `60000` (60s) |
| `KeepAliveIntervalMs` | Keep-alive frequency | `10000` (10s) |
| `ReconnectDelaySeconds` | Initial reconnect delay | `10` |
| `MaxReconnectDelaySeconds` | Max backoff delay | `300` (5min) |

### **Subscription Settings**

| Parameter | Description | Recommended |
|-----------|-------------|-------------|
| `PublishingIntervalMs` | How often server checks for changes | `1000` (1s) |
| `SamplingIntervalMs` | How often server samples data source | `1000` (1s) |
| `QueueSize` | Buffered data changes per node | `10` |

### **Security Settings (CRITICAL)**

| Parameter | Description | Production | Testing |
|-----------|-------------|------------|---------|
| `AcceptUntrustedCertificates` | Accept invalid certs | `false` | `true` |
| `AutoAcceptCertificates` | Auto-accept all certs | `false` | `true` |

⚠️ **WARNING**: Never use `true` for security overrides in production!

### **Node Configuration**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `NodeId` | OPC UA node identifier | `ns=2;s=Device.Temperature` |
| `DisplayName` | Friendly name for logs | `Temperature Sensor 1` |
| `SamplingIntervalMs` | Override global sampling | `500` (optional) |
| `DeadbandType` | Filter type | `Absolute`, `Percent`, `None` |
| `DeadbandValue` | Deadband threshold | `0.5` (units or %) |

**NodeId Formats:**
- Numeric: `ns=2;i=1001`
- String: `ns=2;s=Device.Temp`
- GUID: `ns=2;g=550e8400-e29b-41d4-a716-446655440000`

---

## HOW IT WORKS

### **Startup Sequence**

1. Service starts (Worker.ExecuteAsync)
2. Configuration validation
3. System initialization delay (15s)
4. **OPC UA client starts** (parallel to watchdog)
   - Application instance created
   - Certificate validation configured
   - Endpoint discovery
   - Session creation
   - Subscription setup
   - Monitored items added
5. Flutter watchdog loop begins
6. Both run independently

### **Data Flow**

```
OPC UA Server
    ↓ (subscription)
OPC UA Client Service
    ↓ (MonitoredItem_Notification)
Normalize to OpcUaDataValue
    ↓ (DataReceived event)
Worker.OpcUaClient_DataReceived()
    ↓
Your Processing Logic
    ↓
Database / Message Queue / API / Alerts
```

### **Reconnection Logic**

```
Connection Lost
    ↓
Keep-alive detects failure
    ↓
Trigger reconnection loop
    ↓
Apply exponential backoff (10s → 20s → 40s → 80s → 160s → 300s max)
    ↓
Attempt reconnection
    ↓
Success → Reset backoff, continue
Failure → Increase backoff, retry
```

---

## DATA PROCESSING

### **Handling Data in Worker.cs**

Current implementation (line ~150):

```csharp
private void OpcUaClient_DataReceived(object? sender, OpcUaDataValue data)
{
    try
    {
        // Log data (production: use LogInformation sparingly)
        _logger.LogInformation(
            "OPC UA Data: {DisplayName} = {Value} [{Type}], Quality: {Quality}",
            data.DisplayName,
            data.ValueAsString,
            data.DataType,
            data.StatusDescription);

        // TODO: Add your processing logic here
        
        // Example: Type-safe value extraction
        if (data.TryGetDouble(out double value))
        {
            if (value > 100.0)
            {
                _logger.LogWarning("ALARM: {DisplayName} exceeded threshold: {Value}",
                    data.DisplayName, value);
            }
        }
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error processing OPC UA data");
    }
}
```

### **Integration Examples**

#### **1. Store to Database (Entity Framework)**

```csharp
private async void OpcUaClient_DataReceived(object? sender, OpcUaDataValue data)
{
    try
    {
        using var dbContext = new ScadaDbContext();
        var record = new DataPoint
        {
            NodeId = data.NodeId,
            DisplayName = data.DisplayName,
            Value = data.ValueAsString,
            Timestamp = data.SourceTimestamp,
            Quality = data.StatusDescription
        };
        
        dbContext.DataPoints.Add(record);
        await dbContext.SaveChangesAsync();
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Database write failed for {NodeId}", data.NodeId);
    }
}
```

#### **2. Publish to MQTT**

```csharp
private readonly IMqttClient _mqttClient; // Injected via constructor

private void OpcUaClient_DataReceived(object? sender, OpcUaDataValue data)
{
    try
    {
        var message = new MqttApplicationMessageBuilder()
            .WithTopic($"scada/{data.DisplayName}")
            .WithPayload(JsonSerializer.Serialize(data))
            .WithQualityOfServiceLevel(MqttQualityOfServiceLevel.AtLeastOnce)
            .Build();
        
        _ = _mqttClient.PublishAsync(message);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "MQTT publish failed");
    }
}
```

#### **3. Forward to REST API**

```csharp
private readonly HttpClient _httpClient; // Injected

private async void OpcUaClient_DataReceived(object? sender, OpcUaDataValue data)
{
    try
    {
        var json = JsonSerializer.Serialize(data);
        var content = new StringContent(json, Encoding.UTF8, "application/json");
        
        var response = await _httpClient.PostAsync(
            "https://api.example.com/scada/data",
            content);
        
        response.EnsureSuccessStatusCode();
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "API forward failed");
    }
}
```

#### **4. In-Memory Cache for Real-Time Access**

```csharp
private readonly ConcurrentDictionary<string, OpcUaDataValue> _latestValues = new();

private void OpcUaClient_DataReceived(object? sender, OpcUaDataValue data)
{
    _latestValues[data.NodeId] = data;
    
    // Check for alarm conditions
    if (data.DisplayName.Contains("Temperature") && data.TryGetDouble(out double temp))
    {
        if (temp > 150.0)
        {
            TriggerAlarm("High Temperature", data);
        }
    }
}

public OpcUaDataValue? GetLatestValue(string nodeId)
{
    return _latestValues.TryGetValue(nodeId, out var value) ? value : null;
}
```

---

## SECURITY HARDENING

### **Production Certificate Setup**

1. **Generate Application Certificate**
   ```powershell
   # OPC Foundation SDK handles this automatically on first run
   # Certificate stored in: %LOCALAPPDATA%\OPC Foundation\pki
   ```

2. **Configure Server Trust**
   - Copy server certificate to trusted store
   - Or configure server to trust client certificate
   - Set `AcceptUntrustedCertificates: false`
   - Set `AutoAcceptCertificates: false`

3. **Use Secure Authentication**
   ```json
   {
     "AuthenticationMode": "UsernamePassword",
     "Username": "scada_readonly",
     "Password": "env:OPC_UA_PASSWORD"  // Use environment variable
   }
   ```

4. **Encrypt Password in Configuration**
   ```powershell
   # Use Windows DPAPI or Azure Key Vault
   # Never commit passwords to source control
   ```

### **Network Security**

- Use firewall rules to restrict OPC UA server access
- Enable TLS/SSL at network layer if supported
- Use VPN for remote OPC UA connections
- Monitor for unauthorized connection attempts

---

## MONITORING & DIAGNOSTICS

### **Log Events**

| Event | Level | Meaning |
|-------|-------|---------|
| `OPC UA Client Starting` | Information | Initialization beginning |
| `Session created successfully` | Information | Connected to server |
| `Subscription created with X items` | Information | Monitoring configured |
| `Data received: {Name} = {Value}` | Debug/Information | Data update |
| `Keep-alive failed` | Warning | Connection issue detected |
| `Applying exponential backoff` | Warning | Reconnection in progress |
| `Failed to connect` | Error | Connection failed |
| `VALIDATION ERROR` | Error | Configuration problem |

### **Connection Health**

```powershell
# View OPC UA connection events
Get-Content C:\Logs\ScadaWatcher\*.log | Select-String "OPC UA"

# Check for connection issues
Get-Content C:\Logs\ScadaWatcher\*.log | Select-String "reconnect|backoff"

# Monitor data flow
Get-Content C:\Logs\ScadaWatcher\*.log -Tail 100 -Wait | Select-String "Data received"
```

### **Performance Metrics**

Monitor these indicators:
- **Data rate**: Messages per second
- **Reconnection frequency**: Should be rare
- **Backoff delays**: Increasing = persistent problems
- **Memory usage**: Watch for leaks
- **CPU usage**: Should be < 5% for OPC UA

---

## TROUBLESHOOTING

### **Problem: OPC UA Client Won't Start**

**Symptoms:**
```
VALIDATION ERROR: EndpointUrl is not configured
```

**Solution:**
1. Check `appsettings.json` has `OpcUa` section
2. Verify `Enabled: true`
3. Confirm `EndpointUrl` format: `opc.tcp://host:port/path`
4. Test server connectivity: `Test-NetConnection -ComputerName host -Port port`

---

### **Problem: Connection Refused**

**Symptoms:**
```
Failed to connect to OPC UA server
Endpoint discovery failed
```

**Solution:**
1. Verify server is running
2. Check firewall allows port (typically 4840)
3. Confirm endpoint URL is exact (case-sensitive path)
4. Try with OPC UA test client (e.g., UAExpert)
5. Check server logs for connection attempts

---

### **Problem: Certificate Validation Fails**

**Symptoms:**
```
Rejecting untrusted certificate
Certificate validation issue: BadCertificateUntrusted
```

**Solution (Testing):**
```json
{
  "AcceptUntrustedCertificates": true,
  "AutoAcceptCertificates": true
}
```

**Solution (Production):**
1. Exchange certificates with server administrator
2. Add server cert to trusted store
3. Configure server to trust client cert
4. Set security overrides to `false`

---

### **Problem: No Data Received**

**Symptoms:**
```
Subscription created successfully
No "Data received" log entries
```

**Solution:**
1. Verify NodeIds are correct (case-sensitive!)
2. Check nodes exist on server (use UAExpert to browse)
3. Confirm nodes are readable (access rights)
4. Check deadband settings (may filter changes)
5. Verify server is updating values

---

### **Problem: Rapid Reconnections**

**Symptoms:**
```
Applying exponential backoff: 10 seconds
Applying exponential backoff: 20 seconds
Applying exponential backoff: 40 seconds
```

**Solution:**
1. Check server stability
2. Review network connectivity
3. Increase session timeout
4. Check server capacity/load
5. Review server logs for errors

---

## PERFORMANCE TUNING

### **High-Frequency Data (< 100ms)**

```json
{
  "PublishingIntervalMs": 100,
  "SamplingIntervalMs": 50,
  "QueueSize": 50
}
```

**Notes:**
- Higher CPU usage
- More network traffic
- Faster response to changes

### **Low-Frequency Data (> 10s)**

```json
{
  "PublishingIntervalMs": 10000,
  "SamplingIntervalMs": 10000,
  "QueueSize": 5
}
```

**Notes:**
- Lower CPU usage
- Reduced network traffic
- Delayed change detection

### **Deadband Filtering**

Reduce noise from analog sensors:

```json
{
  "NodeId": "ns=2;s=TemperatureSensor",
  "DeadbandType": "Absolute",
  "DeadbandValue": 0.5  // Only notify if change > ±0.5 units
}
```

```json
{
  "NodeId": "ns=2;s=FlowRate",
  "DeadbandType": "Percent",
  "DeadbandValue": 2.0  // Only notify if change > ±2%
}
```

---

## TESTING WITHOUT OPC UA SERVER

### **Use Free OPC UA Test Servers**

**Prosys OPC UA Simulation Server**
- Download: https://www.prosysopc.com/products/opc-ua-simulation-server/
- Free for testing
- Configurable simulation nodes

**Unified Automation UaExpert (Client + Demo Server)**
- Download: https://www.unified-automation.com/downloads/opc-ua-clients.html
- Includes demo server
- Excellent for testing

**Configuration for Test Server:**
```json
{
  "EndpointUrl": "opc.tcp://localhost:53530/OPCUA/SimulationServer",
  "SecurityMode": "None",
  "AcceptUntrustedCertificates": true,
  "Nodes": [
    {
      "NodeId": "ns=3;i=1001",  // Counter
      "DisplayName": "Test Counter"
    }
  ]
}
```

---

## PRODUCTION DEPLOYMENT CHECKLIST

- [ ] Update `EndpointUrl` to production server
- [ ] Set `SecurityMode: "SignAndEncrypt"`
- [ ] Set `SecurityPolicy: "Basic256Sha256"`
- [ ] Configure authentication credentials
- [ ] Set `AcceptUntrustedCertificates: false`
- [ ] Set `AutoAcceptCertificates: false`
- [ ] Exchange and trust certificates
- [ ] Test connection manually
- [ ] Update NodeIds to actual production nodes
- [ ] Implement data processing logic (database/MQTT/API)
- [ ] Configure deadband filters appropriately
- [ ] Test reconnection behavior
- [ ] Monitor logs for errors
- [ ] Document node mappings
- [ ] Set up alerting for connection failures

---

## SUMMARY

✅ **OPC UA client is production-ready**  
✅ **Completely separate from Flutter watchdog**  
✅ **Never crashes the service**  
✅ **Automatic reconnection with backoff**  
✅ **Subscription-based (efficient, event-driven)**  
✅ **Comprehensive logging**  
✅ **Externally configurable**  
✅ **Security policy support**  
✅ **Read-only for safety**  

**Your SCADA Watcher Service now provides industrial-grade data acquisition alongside process supervision.**
