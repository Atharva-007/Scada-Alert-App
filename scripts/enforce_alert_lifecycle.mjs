#!/usr/bin/env node

import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_ACTIVE_COLLECTION = 'alerts_active';
const DEFAULT_HISTORY_COLLECTION = 'alerts_history';
const DEFAULT_BATCH_SIZE = 400;
const DEFAULT_OUT_DIR = 'migration_output';

function parseArgs(argv) {
  const args = {
    projectId: null,
    serviceAccount: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
    activeCollection: DEFAULT_ACTIVE_COLLECTION,
    historyCollection: DEFAULT_HISTORY_COLLECTION,
    batchSize: DEFAULT_BATCH_SIZE,
    outDir: DEFAULT_OUT_DIR,
    apply: false,
    dryRun: true,
    verbose: false,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }

    const [rawKey, inlineValue] = token.slice(2).split('=', 2);
    const key = rawKey.trim();
    const nextValue = inlineValue ?? argv[index + 1];
    const consumeNext = inlineValue === undefined;

    switch (key) {
      case 'help':
        args.help = true;
        break;
      case 'project-id':
        args.projectId = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'service-account':
        args.serviceAccount = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'active-collection':
        args.activeCollection = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'history-collection':
        args.historyCollection = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'batch-size':
        args.batchSize = Number.parseInt(nextValue, 10);
        if (consumeNext) index += 1;
        break;
      case 'out-dir':
        args.outDir = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'apply':
        args.apply = true;
        args.dryRun = false;
        break;
      case 'dry-run':
        args.dryRun = true;
        args.apply = false;
        break;
      case 'verbose':
        args.verbose = true;
        break;
      default:
        throw new Error(`Unknown argument: --${key}`);
    }
  }

  if (!Number.isFinite(args.batchSize) || args.batchSize < 1 || args.batchSize > 500) {
    throw new Error('--batch-size must be between 1 and 500.');
  }

  return args;
}

function printHelp() {
  console.log(`
Firestore alert lifecycle enforcement tool

Usage:
  node scripts/enforce_alert_lifecycle.mjs [options]

Options:
  --project-id <id>           Firebase project id. Falls back to .firebaserc.
  --service-account <path>    Service account JSON path. Falls back to env vars.
  --active-collection <name>  Active collection name. Default: ${DEFAULT_ACTIVE_COLLECTION}
  --history-collection <name> History collection name. Default: ${DEFAULT_HISTORY_COLLECTION}
  --batch-size <n>            Firestore batch size. Default: ${DEFAULT_BATCH_SIZE}
  --out-dir <path>            Report output directory. Default: ${DEFAULT_OUT_DIR}
  --apply                     Apply the migration. Default mode is dry run.
  --dry-run                   Plan only, do not write.
  --verbose                   Print per-alert action lines.
  --help                      Show this help text.

Behavior:
  - Keeps open and acknowledged-pending alerts in ${DEFAULT_ACTIVE_COLLECTION}
  - Keeps approved, rejected, and cleared alerts in ${DEFAULT_HISTORY_COLLECTION}
  - Normalizes lowercase lifecycle fields and legacy aliases
  - Consolidates duplicates when the same alert id exists in both collections
`);
}

async function fileExists(filePath) {
  try {
    await access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readJsonIfExists(filePath) {
  if (!(await fileExists(filePath))) {
    return null;
  }

  const raw = await readFile(filePath, 'utf8');
  return JSON.parse(raw);
}

async function resolveProjectId(cliProjectId) {
  if (cliProjectId && cliProjectId.trim()) {
    return cliProjectId.trim();
  }

  const firebaseRc = await readJsonIfExists(path.join(process.cwd(), '.firebaserc'));
  const defaultProject = firebaseRc?.projects?.default;
  if (defaultProject && String(defaultProject).trim()) {
    return String(defaultProject).trim();
  }

  return null;
}

async function readServiceAccountPathsFromScadaWatcherConfig() {
  const configFiles = [
    path.join(process.cwd(), 'ScadaWatcherService', 'appsettings.json'),
    path.join(process.cwd(), 'ScadaWatcherService', 'appsettings.Development.json'),
  ];

  const configuredPaths = [];
  for (const configFile of configFiles) {
    const config = await readJsonIfExists(configFile);
    const configuredPath = config?.Firebase?.ServiceAccountJsonPath;
    if (!configuredPath) {
      continue;
    }

    configuredPaths.push({
      source: configFile,
      path: resolveCandidatePath(configuredPath),
    });
  }

  return configuredPaths;
}

function resolveCandidatePath(candidate) {
  if (!candidate || !String(candidate).trim()) {
    return null;
  }

  const trimmed = String(candidate).trim();
  return path.isAbsolute(trimmed)
    ? trimmed
    : path.resolve(process.cwd(), trimmed);
}

async function resolveCredential(args, fallbackProjectId) {
  const explicitServiceAccount = resolveCandidatePath(args.serviceAccount);
  if (explicitServiceAccount && !(await fileExists(explicitServiceAccount))) {
    throw new Error(
      `The service account file passed to --service-account was not found: ${explicitServiceAccount}`,
    );
  }

  const configuredServiceAccounts = await readServiceAccountPathsFromScadaWatcherConfig();
  const candidates = [
    explicitServiceAccount,
    ...configuredServiceAccounts.map((entry) => entry.path),
    'service-account.json',
    'firebase-service-account.json',
    path.join('config', 'firebase-service-account.json'),
  ]
    .map(resolveCandidatePath)
    .filter(Boolean);

  for (const candidate of candidates) {
    if (!(await fileExists(candidate))) {
      continue;
    }

    const serviceAccount = JSON.parse(await readFile(candidate, 'utf8'));
    return {
      projectId: fallbackProjectId ?? serviceAccount.project_id ?? null,
      credential: cert(serviceAccount),
      credentialSource: candidate,
    };
  }

  if (configuredServiceAccounts.length > 0) {
    const configuredLocations = configuredServiceAccounts
      .map((entry) => `${entry.path} (from ${entry.source})`)
      .join(', ');

    throw new Error(
      `No service account JSON file was found. The Windows service configuration points to: ${configuredLocations}. Place the Firebase Admin key at one of those paths, or pass --service-account with the real file path.`,
    );
  }

  return {
    projectId: fallbackProjectId,
    credential: applicationDefault(),
    credentialSource: 'applicationDefault()',
  };
}

function normalizeString(value, fallback = '') {
  if (value === null || value === undefined) {
    return fallback;
  }

  const normalized = String(value).trim();
  return normalized || fallback;
}

function normalizeLower(value, fallback = '') {
  return normalizeString(value, fallback).toLowerCase();
}

function normalizeSeverity(value) {
  const severity = normalizeLower(value, 'info');
  switch (severity) {
    case 'emergency':
    case 'p1':
      return 'critical';
    case 'high':
    case 'critical':
      return severity === 'high' ? 'high' : 'critical';
    case 'warning':
    case 'medium':
    case 'p2':
    case 'p3':
      return severity === 'medium' ? 'medium' : 'warning';
    case 'low':
    case 'info':
    default:
      return severity || 'info';
  }
}

function normalizeNumber(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value.trim());
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return fallback;
}

function normalizeInteger(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }

  if (typeof value === 'string') {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return fallback;
}

function normalizeBoolean(value, fallback = false) {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].includes(normalized)) {
      return true;
    }
    if (['false', '0', 'no', 'n'].includes(normalized)) {
      return false;
    }
  }

  return fallback;
}

function toTimestamp(value) {
  if (!value) {
    return null;
  }

  if (value instanceof Timestamp) {
    return value;
  }

  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return Timestamp.fromDate(value);
  }

  if (typeof value === 'object') {
    if (typeof value.toDate === 'function') {
      const date = value.toDate();
      if (date instanceof Date && !Number.isNaN(date.getTime())) {
        return Timestamp.fromDate(date);
      }
    }

    const seconds = value._seconds ?? value.seconds;
    const nanoseconds = value._nanoseconds ?? value.nanoseconds ?? 0;
    if (typeof seconds === 'number') {
      return new Timestamp(seconds, nanoseconds);
    }
  }

  if (typeof value === 'number' && Number.isFinite(value)) {
    const asDate =
      value > 1_000_000_000_000
        ? new Date(value)
        : new Date(value * 1000);
    if (!Number.isNaN(asDate.getTime())) {
      return Timestamp.fromDate(asDate);
    }
  }

  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      return null;
    }

    const asNumber = Number(trimmed);
    if (Number.isFinite(asNumber)) {
      return toTimestamp(asNumber);
    }

    const asDate = new Date(trimmed);
    if (!Number.isNaN(asDate.getTime())) {
      return Timestamp.fromDate(asDate);
    }
  }

  return null;
}

function firstValue(data, keys) {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(data, key) && data[key] !== undefined && data[key] !== null) {
      return data[key];
    }
  }

  return null;
}

function firstString(data, keys, fallback = '') {
  for (const key of keys) {
    const value = firstValue(data, [key]);
    const normalized = normalizeString(value, '');
    if (normalized) {
      return normalized;
    }
  }

  return fallback;
}

function firstTimestamp(data, keys) {
  for (const key of keys) {
    const timestamp = toTimestamp(firstValue(data, [key]));
    if (timestamp) {
      return timestamp;
    }
  }

  return null;
}

function firstBoolean(data, keys, fallback = false) {
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      continue;
    }
    return normalizeBoolean(data[key], fallback);
  }

  return fallback;
}

function firstNumber(data, keys, fallback = 0) {
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      continue;
    }
    return normalizeNumber(data[key], fallback);
  }

  return fallback;
}

function firstInteger(data, keys, fallback = 0) {
  for (const key of keys) {
    if (!Object.prototype.hasOwnProperty.call(data, key)) {
      continue;
    }
    return normalizeInteger(data[key], fallback);
  }

  return fallback;
}

function firstStringArray(data, keys) {
  const value = firstValue(data, keys);
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => normalizeString(item, ''))
    .filter(Boolean);
}

function firstObjectArray(data, keys) {
  const value = firstValue(data, keys);
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter((item) => item && typeof item === 'object');
}

function getBestTimestamp(data) {
  return (
    firstTimestamp(data, ['lastUpdatedTime', 'updated_at', 'updatedAt']) ??
    firstTimestamp(data, ['clearedAt', 'clearedTime', 'resolved_at']) ??
    firstTimestamp(data, ['approvedAt']) ??
    firstTimestamp(data, ['rejectedAt']) ??
    firstTimestamp(data, ['acknowledgedAt', 'acknowledged_at']) ??
    firstTimestamp(data, ['raisedAt', 'timestamp', 'created_at', 'createdAt'])
  );
}

function chooseMergedData(activeData, historyData) {
  if (activeData && historyData) {
    const activeTime = getBestTimestamp(activeData)?.toMillis() ?? 0;
    const historyTime = getBestTimestamp(historyData)?.toMillis() ?? 0;
    return activeTime >= historyTime
      ? { ...historyData, ...activeData }
      : { ...activeData, ...historyData };
  }

  return activeData ? { ...activeData } : { ...historyData };
}

function classifyLifecycle(merged) {
  const status = normalizeLower(firstString(merged, ['status'], ''));
  const approvalStatus = normalizeLower(firstString(merged, ['approvalStatus'], ''));
  const acknowledged =
    firstBoolean(merged, ['isAcknowledged', 'acknowledged'], false) ||
    Boolean(firstTimestamp(merged, ['acknowledgedAt', 'acknowledged_at'])) ||
    Boolean(firstString(merged, ['acknowledgedBy', 'acknowledged_by'], '')) ||
    Boolean(firstString(merged, ['acknowledgedComment', 'acknowledgement_detail'], ''));

  const approved = approvalStatus === 'approved' || status === 'approved' || Boolean(firstTimestamp(merged, ['approvedAt']));
  const rejected = approvalStatus === 'rejected' || status === 'rejected' || Boolean(firstTimestamp(merged, ['rejectedAt']));
  const cleared = status === 'cleared' || Boolean(firstTimestamp(merged, ['clearedAt', 'clearedTime', 'resolved_at']));

  if (rejected) {
    return {
      targetCollection: DEFAULT_HISTORY_COLLECTION,
      status: 'rejected',
      approvalStatus: 'rejected',
      isActive: false,
      isAcknowledged: true,
    };
  }

  if (approved) {
    return {
      targetCollection: DEFAULT_HISTORY_COLLECTION,
      status: 'approved',
      approvalStatus: 'approved',
      isActive: false,
      isAcknowledged: true,
    };
  }

  if (cleared) {
    return {
      targetCollection: DEFAULT_HISTORY_COLLECTION,
      status: 'cleared',
      approvalStatus: 'approved',
      isActive: false,
      isAcknowledged: acknowledged,
    };
  }

  if (status === 'acknowledged' || acknowledged) {
    return {
      targetCollection: DEFAULT_ACTIVE_COLLECTION,
      status: 'acknowledged',
      approvalStatus: 'pending',
      isActive: true,
      isAcknowledged: true,
    };
  }

  return {
    targetCollection: DEFAULT_ACTIVE_COLLECTION,
    status: 'active',
    approvalStatus: 'pending',
    isActive: true,
    isAcknowledged: false,
  };
}

function compactObject(object) {
  return Object.fromEntries(
    Object.entries(object).filter(([, value]) => value !== undefined),
  );
}

function buildCanonicalDocument(alertId, merged, lifecycle, args) {
  let raisedAt =
    firstTimestamp(merged, ['raisedAt', 'timestamp', 'created_at', 'createdAt']) ??
    Timestamp.now();
  let acknowledgedAt = firstTimestamp(merged, ['acknowledgedAt', 'acknowledged_at']);
  let approvedAt = firstTimestamp(merged, ['approvedAt']);
  let rejectedAt = firstTimestamp(merged, ['rejectedAt']);
  let clearedAt = firstTimestamp(merged, ['clearedAt', 'clearedTime', 'resolved_at']);
  let lastUpdatedTime =
    firstTimestamp(merged, ['lastUpdatedTime', 'updated_at', 'updatedAt']) ??
    clearedAt ??
    approvedAt ??
    rejectedAt ??
    acknowledgedAt ??
    raisedAt;

  if (lifecycle.status === 'approved' && !approvedAt) {
    approvedAt = lastUpdatedTime ?? acknowledgedAt ?? raisedAt;
  }

  if (lifecycle.status === 'rejected' && !rejectedAt) {
    rejectedAt = lastUpdatedTime ?? acknowledgedAt ?? raisedAt;
  }

  if (lifecycle.targetCollection === DEFAULT_HISTORY_COLLECTION && !clearedAt) {
    clearedAt = approvedAt ?? rejectedAt ?? lastUpdatedTime ?? acknowledgedAt ?? raisedAt;
  }

  lastUpdatedTime =
    lastUpdatedTime ??
    clearedAt ??
    approvedAt ??
    rejectedAt ??
    acknowledgedAt ??
    raisedAt;

  const canonicalId = firstString(merged, ['alertId', 'id'], alertId) || alertId;
  const name = firstString(merged, ['name', 'alert', 'title', 'alarm_name'], `Alert ${canonicalId}`);
  const description = firstString(
    merged,
    ['description', 'detail', 'message', 'alarm_text'],
    '',
  );
  const severity = normalizeSeverity(firstString(merged, ['severity'], 'info'));
  const source = firstString(merged, ['source', 'equipment', 'location'], 'Unknown');
  const equipment = firstString(merged, ['equipment', 'source'], source);
  const tagName = firstString(merged, ['tagName', 'nodeId', 'equipment', 'source'], canonicalId);
  const location = firstString(merged, ['location'], '');
  const acknowledgedBy = firstString(merged, ['acknowledgedBy', 'acknowledged_by'], '');
  const acknowledgedComment = firstString(
    merged,
    ['acknowledgedComment', 'acknowledgement_detail', 'notes'],
    '',
  );
  const notes = firstString(merged, ['notes'], '');
  const approvedBy = firstString(merged, ['approvedBy'], '');
  const rejectedBy = firstString(merged, ['rejectedBy'], '');
  const rejectionReason = firstString(merged, ['rejectionReason'], '');
  const alertType = firstString(merged, ['alertType'], '');
  const condition = firstString(merged, ['condition', 'alertType', 'category'], lifecycle.status);
  const currentValue = firstNumber(merged, ['currentValue', 'triggerValue', 'value'], 0);
  const triggerValue = firstNumber(merged, ['triggerValue', 'currentValue', 'value'], currentValue);
  const threshold = firstNumber(merged, ['threshold'], 0);
  const escalationCount = firstInteger(merged, ['escalationCount'], 0);
  const escalationLevel = firstInteger(merged, ['escalationLevel', 'priority'], escalationCount);
  const suppressionCount = firstInteger(merged, ['suppressionCount'], 0);
  const relatedAlertIds = firstStringArray(merged, ['relatedAlertIds']);
  const trendData = firstObjectArray(merged, ['trendData']);
  const isSuppressed = firstBoolean(merged, ['isSuppressed'], false);

  const canonicalDocument = compactObject({
    ...merged,
    id: canonicalId,
    alertId: canonicalId,
    name,
    alert: name,
    description,
    detail: description,
    message: description,
    severity,
    source,
    equipment,
    location: location || null,
    tagName,
    nodeId: tagName,
    currentValue,
    triggerValue,
    threshold,
    condition,
    alertType: alertType || null,
    raisedAt,
    timestamp: raisedAt,
    status: lifecycle.status,
    approvalStatus: lifecycle.approvalStatus,
    isActive: lifecycle.isActive,
    isAcknowledged: lifecycle.isAcknowledged,
    acknowledged: lifecycle.isAcknowledged,
    acknowledgedAt: acknowledgedAt ?? null,
    acknowledged_at: acknowledgedAt ?? null,
    acknowledgedBy: acknowledgedBy || null,
    acknowledged_by: acknowledgedBy || null,
    acknowledgedComment: acknowledgedComment || null,
    acknowledgement_detail: acknowledgedComment || null,
    approvedAt: approvedAt ?? null,
    approvedBy: approvedBy || null,
    rejectedAt: rejectedAt ?? null,
    rejectedBy: rejectedBy || null,
    rejectionReason: rejectionReason || null,
    clearedAt: clearedAt ?? null,
    clearedTime: clearedAt ?? null,
    notes: notes || null,
    isSuppressed,
    escalationCount,
    escalationLevel,
    suppressionCount,
    relatedAlertIds,
    trendData,
    created_at: raisedAt,
    updated_at: lastUpdatedTime,
    lastUpdatedTime,
    __normalizedBy: 'scripts/enforce_alert_lifecycle.mjs',
  });

  delete canonicalDocument.__path__;
  return canonicalDocument;
}

function resolveActionType(hasActive, hasHistory, lifecycle) {
  if (lifecycle.targetCollection === DEFAULT_HISTORY_COLLECTION) {
    if (hasActive && !hasHistory) {
      return 'move_to_history';
    }
    if (hasActive && hasHistory) {
      return 'consolidate_history';
    }
    return 'normalize_history';
  }

  if (!hasActive && hasHistory) {
    return 'move_to_active';
  }
  if (hasActive && hasHistory) {
    return 'consolidate_active';
  }
  return 'normalize_active';
}

function incrementSummary(summary, key) {
  summary[key] = (summary[key] ?? 0) + 1;
}

async function applyOperations(db, operations, batchSize) {
  let batch = db.batch();
  let opCount = 0;
  let commitCount = 0;

  for (const operation of operations) {
    const ref = db.collection(operation.collection).doc(operation.id);
    if (operation.kind === 'set') {
      batch.set(ref, operation.data);
    } else if (operation.kind === 'delete') {
      batch.delete(ref);
    } else {
      throw new Error(`Unknown operation kind: ${operation.kind}`);
    }

    opCount += 1;
    if (opCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
      commitCount += 1;
    }
  }

  if (opCount > 0) {
    await batch.commit();
    commitCount += 1;
  }

  return commitCount;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }

  const projectId = await resolveProjectId(args.projectId);
  const credentialConfig = await resolveCredential(args, projectId);
  const resolvedProjectId = credentialConfig.projectId ?? projectId;
  if (!resolvedProjectId) {
    throw new Error('Unable to resolve Firebase project id. Use --project-id or configure .firebaserc.');
  }

  if (!getApps().length) {
    initializeApp({
      credential: credentialConfig.credential,
      projectId: resolvedProjectId,
    });
  }

  const db = getFirestore();
  const outDir = path.resolve(process.cwd(), args.outDir);
  await mkdir(outDir, { recursive: true });

  console.log(`Project: ${resolvedProjectId}`);
  console.log(`Mode: ${args.apply ? 'APPLY' : 'DRY RUN'}`);
  console.log(`Credential source: ${credentialConfig.credentialSource}`);
  console.log(`Active collection: ${args.activeCollection}`);
  console.log(`History collection: ${args.historyCollection}`);

  const [activeSnapshot, historySnapshot] = await Promise.all([
    db.collection(args.activeCollection).get(),
    db.collection(args.historyCollection).get(),
  ]);

  const activeById = new Map();
  for (const doc of activeSnapshot.docs) {
    activeById.set(doc.id, doc.data());
  }

  const historyById = new Map();
  for (const doc of historySnapshot.docs) {
    historyById.set(doc.id, doc.data());
  }

  const alertIds = new Set([...activeById.keys(), ...historyById.keys()]);
  const report = {
    generatedAt: new Date().toISOString(),
    projectId: resolvedProjectId,
    mode: args.apply ? 'apply' : 'dry-run',
    credentialSource: credentialConfig.credentialSource,
    collections: {
      active: args.activeCollection,
      history: args.historyCollection,
    },
    scanned: {
      activeDocuments: activeSnapshot.size,
      historyDocuments: historySnapshot.size,
      uniqueAlerts: alertIds.size,
    },
    summary: {
      move_to_history: 0,
      move_to_active: 0,
      consolidate_history: 0,
      consolidate_active: 0,
      normalize_history: 0,
      normalize_active: 0,
      delete_active: 0,
      delete_history: 0,
      set_active: 0,
      set_history: 0,
    },
    actions: [],
  };

  const operations = [];

  for (const alertId of [...alertIds].sort()) {
    const activeData = activeById.get(alertId) ?? null;
    const historyData = historyById.get(alertId) ?? null;
    const merged = chooseMergedData(activeData, historyData);
    const lifecycle = classifyLifecycle(merged);
    const targetCollection =
      lifecycle.targetCollection === DEFAULT_ACTIVE_COLLECTION
        ? args.activeCollection
        : args.historyCollection;
    const canonicalDocument = buildCanonicalDocument(alertId, merged, lifecycle, args);
    const actionType = resolveActionType(Boolean(activeData), Boolean(historyData), lifecycle);
    const action = {
      id: alertId,
      action: actionType,
      from: {
        active: Boolean(activeData),
        history: Boolean(historyData),
      },
      toCollection: targetCollection,
      status: lifecycle.status,
      approvalStatus: lifecycle.approvalStatus,
      isActive: lifecycle.isActive,
      isAcknowledged: lifecycle.isAcknowledged,
    };

    report.actions.push(action);
    incrementSummary(report.summary, actionType);

    operations.push({
      kind: 'set',
      collection: targetCollection,
      id: alertId,
      data: canonicalDocument,
    });
    incrementSummary(
      report.summary,
      targetCollection === args.activeCollection ? 'set_active' : 'set_history',
    );

    if (targetCollection === args.historyCollection && activeData) {
      operations.push({
        kind: 'delete',
        collection: args.activeCollection,
        id: alertId,
      });
      incrementSummary(report.summary, 'delete_active');
    }

    if (targetCollection === args.activeCollection && historyData) {
      operations.push({
        kind: 'delete',
        collection: args.historyCollection,
        id: alertId,
      });
      incrementSummary(report.summary, 'delete_history');
    }

    if (args.verbose) {
      console.log(
        `[${action.action}] ${alertId} -> ${targetCollection} (${lifecycle.status}, approval=${lifecycle.approvalStatus})`,
      );
    }
  }

  const reportPath = path.join(outDir, 'firestore_alert_lifecycle_report.json');
  await writeFile(reportPath, JSON.stringify(report, null, 2));

  if (args.apply) {
    const commitCount = await applyOperations(db, operations, args.batchSize);
    console.log(`Applied ${operations.length} Firestore operations in ${commitCount} batch commit(s).`);
  } else {
    console.log(`Planned ${operations.length} Firestore operations. No writes were executed.`);
  }

  console.log(`Report written to ${reportPath}`);
  console.log('Summary:');
  for (const [key, value] of Object.entries(report.summary)) {
    console.log(`  ${key}: ${value}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
