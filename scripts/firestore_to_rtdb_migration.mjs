#!/usr/bin/env node

import { createSign } from 'node:crypto';
import { access, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import os from 'node:os';
import process from 'node:process';

const DEFAULT_SOURCE_PROJECT_ID = 'scadadaralert';
const DEFAULT_DATABASE_ID = '(default)';
const DEFAULT_BATCH_SIZE = 200;
const DEFAULT_OUT_DIR = 'migration_output';
const DEFAULT_BASELINE_MONTH_DAY = '01-26';
const DEFAULT_BASELINE_TIMEZONE = 'UTC';
const SAFE_INT_MAX = BigInt(Number.MAX_SAFE_INTEGER);
const SAFE_INT_MIN = BigInt(Number.MIN_SAFE_INTEGER);
const DATE_FIELD_PRIORITY = [
  'createdAt',
  'created_at',
  'timestamp',
  'raisedAt',
  'raised_at',
  'date',
  'eventDate',
  'archivedAt',
  'lastUpdatedTime',
  'updatedAt',
  'updated_at',
  'clearedTime',
  'acknowledgedAt',
  'approvedAt',
  'rejectedAt',
];

function parseArgs(argv) {
  const args = {
    sourceProjectId: DEFAULT_SOURCE_PROJECT_ID,
    sourceCandidates: [],
    databaseId: DEFAULT_DATABASE_ID,
    targetProjectId: null,
    targetDatabaseUrl: null,
    serviceAccount: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
    accessToken: process.env.FIREBASE_OAUTH_ACCESS_TOKEN || null,
    batchSize: DEFAULT_BATCH_SIZE,
    outDir: DEFAULT_OUT_DIR,
    importMethod: 'none',
    importPath: '/',
    executeImport: false,
    dryRun: false,
    pretty: true,
    cliProjectSwitch: true,
    writeCliCommands: true,
    integerOverflowMode: 'string',
    baselineMonthDay: DEFAULT_BASELINE_MONTH_DAY,
    baselineTimezone: DEFAULT_BASELINE_TIMEZONE,
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

    const setValue = (value) => {
      args[key.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase())] = value;
    };

    switch (key) {
      case 'help':
        args.help = true;
        break;
      case 'source-project-id':
      case 'target-project-id':
      case 'target-database-url':
      case 'service-account':
      case 'access-token':
      case 'out-dir':
      case 'database-id':
      case 'import-method':
      case 'import-path':
      case 'integer-overflow-mode':
      case 'baseline-month-day':
      case 'baseline-timezone':
        setValue(nextValue);
        if (consumeNext) {
          index += 1;
        }
        break;
      case 'source-candidates':
        args.sourceCandidates = String(nextValue)
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean);
        if (consumeNext) {
          index += 1;
        }
        break;
      case 'batch-size':
        args.batchSize = Number.parseInt(nextValue, 10);
        if (consumeNext) {
          index += 1;
        }
        break;
      case 'execute-import':
        args.executeImport = true;
        break;
      case 'dry-run':
        args.dryRun = true;
        break;
      case 'no-cli-project-switch':
        args.cliProjectSwitch = false;
        break;
      case 'no-write-cli-commands':
        args.writeCliCommands = false;
        break;
      case 'compact':
        args.pretty = false;
        break;
      default:
        throw new Error(`Unknown argument: --${key}`);
    }
  }

  if (!Number.isFinite(args.batchSize) || args.batchSize < 1) {
    throw new Error('--batch-size must be a positive integer.');
  }

  if (!['none', 'cli', 'rest'].includes(args.importMethod)) {
    throw new Error('--import-method must be one of: none, cli, rest.');
  }

  if (!['string', 'number'].includes(args.integerOverflowMode)) {
    throw new Error('--integer-overflow-mode must be one of: string, number.');
  }

  if (!/^\d{2}-\d{2}$/.test(args.baselineMonthDay)) {
    throw new Error('--baseline-month-day must use MM-DD format, for example 01-26.');
  }

  if (args.baselineTimezone !== 'UTC') {
    throw new Error('--baseline-timezone currently supports only UTC.');
  }

  return args;
}

function printHelp() {
  console.log(`
Firestore to Realtime Database migration tool

Usage:
  node scripts/firestore_to_rtdb_migration.mjs [options]

Options:
  --source-project-id <id>         Preferred Firestore source project. Default: ${DEFAULT_SOURCE_PROJECT_ID}
  --source-candidates <a,b,c>      Additional source project candidates to try in order.
  --database-id <id>               Firestore database id. Default: ${DEFAULT_DATABASE_ID}
  --target-project-id <id>         Target Firebase project for Realtime Database import.
  --target-database-url <url>      Target Realtime Database URL.
  --service-account <path>         Service account JSON path.
  --access-token <token>           OAuth access token. Falls back to firebase login session token if available.
  --batch-size <n>                 Page size for Firestore document fetches. Default: ${DEFAULT_BATCH_SIZE}
  --out-dir <dir>                  Output directory. Default: ${DEFAULT_OUT_DIR}
  --baseline-month-day <MM-DD>     Baseline date for schema normalization. Default: ${DEFAULT_BASELINE_MONTH_DAY}
  --baseline-timezone <tz>         Baseline date timezone. Currently only UTC is supported.
  --import-method <none|cli|rest>  Import method. Default: none
  --import-path <path>             Realtime DB path to write. Default: /
  --execute-import                 Execute the Realtime DB import after writing files.
  --dry-run                        Resolve projects and auth, but do not call Firestore.
  --no-cli-project-switch          Skip 'firebase use <project>' when CLI is available.
  --no-write-cli-commands          Skip writing firebase_cli_commands.txt.
  --integer-overflow-mode <mode>   Use 'string' or 'number' for unsafe Firestore integers. Default: string
  --compact                        Write compact JSON instead of pretty JSON.
  --help                           Show this help.
`);
}

async function pathExists(targetPath) {
  try {
    await access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function readJsonIfExists(targetPath) {
  if (!(await pathExists(targetPath))) {
    return null;
  }
  const content = await readFile(targetPath, 'utf8');
  return JSON.parse(content);
}

function jsonStringify(value, pretty) {
  return JSON.stringify(value, null, pretty ? 2 : 0) + '\n';
}

async function writeJson(targetPath, value, pretty) {
  await mkdir(path.dirname(targetPath), { recursive: true });
  await writeFile(targetPath, jsonStringify(value, pretty), 'utf8');
}

async function writeText(targetPath, value) {
  await mkdir(path.dirname(targetPath), { recursive: true });
  await writeFile(targetPath, value, 'utf8');
}

function base64UrlEncode(input) {
  const source = typeof input === 'string' ? Buffer.from(input, 'utf8') : Buffer.from(input);
  return source.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function loadServiceAccount(serviceAccountPath) {
  if (!serviceAccountPath) {
    return null;
  }
  const absolutePath = path.isAbsolute(serviceAccountPath)
    ? serviceAccountPath
    : path.resolve(process.cwd(), serviceAccountPath);
  const content = await readFile(absolutePath, 'utf8');
  return { absolutePath, json: JSON.parse(content) };
}

async function mintServiceAccountAccessToken(serviceAccountPath) {
  const loaded = await loadServiceAccount(serviceAccountPath);
  if (!loaded) {
    return null;
  }

  const serviceAccount = loaded.json;
  const issuedAt = Math.floor(Date.now() / 1000);
  const expiresAt = issuedAt + 3600;
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: [
      'https://www.googleapis.com/auth/datastore',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/cloud-platform',
    ].join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    iat: issuedAt,
    exp: expiresAt,
  };

  const unsignedJwt = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsignedJwt);
  signer.end();
  const signature = signer.sign(serviceAccount.private_key);
  const jwt = `${unsignedJwt}.${base64UrlEncode(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Service account token exchange failed (${response.status}): ${details}`);
  }

  const json = await response.json();
  return {
    type: 'service_account',
    accessToken: json.access_token,
    expiresAt: Date.now() + ((json.expires_in ?? 3600) * 1000),
    serviceAccountPath: loaded.absolutePath,
    clientEmail: serviceAccount.client_email,
    projectId: serviceAccount.project_id ?? null,
  };
}

function getFirebaseCliConfigCandidates() {
  return [
    path.join(process.env.APPDATA ?? '', 'configstore', 'firebase-tools.json'),
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
  ].filter(Boolean);
}

async function loadFirebaseCliSession() {
  for (const candidatePath of getFirebaseCliConfigCandidates()) {
    if (!(await pathExists(candidatePath))) {
      continue;
    }

    try {
      const json = JSON.parse(await readFile(candidatePath, 'utf8'));
      const accessToken = json?.tokens?.access_token ?? null;
      if (!accessToken) {
        continue;
      }

      return {
        type: 'firebase_cli',
        accessToken,
        expiresAt: Number(json?.tokens?.expires_at ?? 0),
        email: json?.user?.email ?? null,
        filePath: candidatePath,
      };
    } catch (error) {
      console.warn(`Warning: unable to read firebase login session from ${candidatePath}: ${error.message}`);
    }
  }

  return null;
}

async function resolveAuth(args) {
  if (args.accessToken) {
    return {
      type: 'explicit_token',
      accessToken: args.accessToken,
      expiresAt: 0,
      source: 'FIREBASE_OAUTH_ACCESS_TOKEN/--access-token',
    };
  }

  if (args.serviceAccount) {
    return mintServiceAccountAccessToken(args.serviceAccount);
  }

  const cliSession = await loadFirebaseCliSession();
  if (!cliSession) {
    return null;
  }

  if (cliSession.expiresAt && cliSession.expiresAt < Date.now()) {
    throw new Error(
      `The firebase login access token at ${cliSession.filePath} has expired. Run 'firebase login' again or use --service-account.`,
    );
  }

  return cliSession;
}

async function loadLocalProjectContext(cwd) {
  const firebaserc = await readJsonIfExists(path.join(cwd, '.firebaserc'));
  const rootGoogleServices = await readJsonIfExists(path.join(cwd, 'google-services.json'));
  const androidGoogleServices = await readJsonIfExists(path.join(cwd, 'android', 'app', 'google-services.json'));
  const googleServices = rootGoogleServices ?? androidGoogleServices;

  return {
    firebasercDefaultProject: firebaserc?.projects?.default ?? null,
    configuredProjectId: googleServices?.project_info?.project_id ?? null,
    configuredRealtimeDatabaseUrl: googleServices?.project_info?.firebase_url ?? null,
    storageBucket: googleServices?.project_info?.storage_bucket ?? null,
  };
}

function resolveSourceProjectCandidates(args, localContext, auth) {
  const ordered = [
    args.sourceProjectId,
    ...args.sourceCandidates,
    auth?.projectId ?? null,
    localContext.firebasercDefaultProject,
    localContext.configuredProjectId,
    'scadadataserver',
    'alert-systems-db',
  ].filter(Boolean);

  return [...new Set(ordered)];
}

function resolveTargetProjectId(args, localContext, accessibleProjectsViaCli) {
  if (args.targetProjectId) {
    return args.targetProjectId;
  }
  if (localContext.firebasercDefaultProject) {
    return localContext.firebasercDefaultProject;
  }
  if (localContext.configuredProjectId) {
    return localContext.configuredProjectId;
  }
  return accessibleProjectsViaCli.at(0) ?? null;
}

function resolveTargetDatabaseUrl(args, localContext, targetProjectId) {
  if (args.targetDatabaseUrl) {
    return args.targetDatabaseUrl;
  }
  if (localContext.configuredRealtimeDatabaseUrl && (!targetProjectId || targetProjectId === localContext.configuredProjectId)) {
    return localContext.configuredRealtimeDatabaseUrl;
  }
  if (targetProjectId) {
    return `https://${targetProjectId}-default-rtdb.firebaseio.com`;
  }
  return null;
}

async function runCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd ?? process.cwd(),
      env: options.env ?? process.env,
      shell: false,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.on('error', reject);
    child.on('close', (code) => {
      resolve({ code, stdout, stderr });
    });
  });
}

async function findFirebaseCliBinary(cwd) {
  const candidates = [
    path.join(cwd, 'node_modules', '.bin', process.platform === 'win32' ? 'firebase.cmd' : 'firebase'),
    process.platform === 'win32' ? 'firebase.cmd' : 'firebase',
    'firebase',
  ];

  for (const candidate of candidates) {
    try {
      const result = await runCommand(candidate, ['--version'], { cwd });
      if (result.code === 0) {
        return candidate;
      }
    } catch {
      // Try the next candidate.
    }
  }

  return null;
}

async function listAccessibleFirebaseProjects(firebaseBinary, cwd) {
  if (!firebaseBinary) {
    return [];
  }

  const result = await runCommand(firebaseBinary, ['projects:list', '--json'], { cwd });
  if (result.code !== 0) {
    return [];
  }

  try {
    const parsed = JSON.parse(result.stdout);
    const results = parsed.result ?? parsed.results ?? parsed.projects ?? [];
    return results
      .map((item) => item.projectId || item.project_id || item.project)
      .filter(Boolean);
  } catch {
    return [];
  }
}

async function switchFirebaseCliProject(firebaseBinary, projectId, cwd) {
  if (!firebaseBinary || !projectId) {
    return false;
  }

  const result = await runCommand(firebaseBinary, ['use', projectId], { cwd });
  return result.code === 0;
}

function encodePathSegments(relativePath) {
  return String(relativePath)
    .split('/')
    .filter(Boolean)
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

function buildFirestoreBaseUrl(projectId, databaseId) {
  return `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/${encodeURIComponent(databaseId)}/documents`;
}

async function googleApiFetch(url, accessToken, options = {}) {
  const response = await fetch(url, {
    method: options.method ?? 'GET',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
      ...(options.headers ?? {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok) {
    const details = await response.text();
    const error = new Error(`Google API request failed (${response.status} ${response.statusText}): ${details}`);
    error.status = response.status;
    throw error;
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

async function listCollectionIds(projectId, databaseId, accessToken, parentDocumentPath = '', batchSize = DEFAULT_BATCH_SIZE) {
  const baseUrl = buildFirestoreBaseUrl(projectId, databaseId);
  const parentSuffix = parentDocumentPath ? `/${encodePathSegments(parentDocumentPath)}` : '';
  let pageToken = null;
  const collectionIds = [];

  do {
    const payload = await googleApiFetch(`${baseUrl}${parentSuffix}:listCollectionIds`, accessToken, {
      method: 'POST',
      body: {
        pageSize: batchSize,
        ...(pageToken ? { pageToken } : {}),
      },
    });

    collectionIds.push(...(payload.collectionIds ?? []));
    pageToken = payload.nextPageToken ?? null;
  } while (pageToken);

  return collectionIds;
}

async function listDocuments(projectId, databaseId, accessToken, collectionPath, batchSize) {
  const baseUrl = buildFirestoreBaseUrl(projectId, databaseId);
  const encodedCollectionPath = encodePathSegments(collectionPath);
  let pageToken = null;
  const documents = [];

  do {
    const url = new URL(`${baseUrl}/${encodedCollectionPath}`);
    url.searchParams.set('pageSize', String(batchSize));
    if (pageToken) {
      url.searchParams.set('pageToken', pageToken);
    }

    const payload = await googleApiFetch(url.toString(), accessToken);
    documents.push(...(payload.documents ?? []));
    pageToken = payload.nextPageToken ?? null;
  } while (pageToken);

  return documents;
}

function extractRelativeDocumentPath(projectId, databaseId, documentName) {
  const prefix = `projects/${projectId}/databases/${databaseId}/documents/`;
  if (!documentName.startsWith(prefix)) {
    throw new Error(`Unexpected Firestore document name: ${documentName}`);
  }
  return documentName.slice(prefix.length);
}

function firestoreValueKind(value) {
  if (!value || typeof value !== 'object') {
    return 'unknown';
  }
  if ('nullValue' in value) return 'null';
  if ('booleanValue' in value) return 'boolean';
  if ('integerValue' in value) return 'integer';
  if ('doubleValue' in value) return 'double';
  if ('timestampValue' in value) return 'timestamp';
  if ('stringValue' in value) return 'string';
  if ('bytesValue' in value) return 'bytes';
  if ('referenceValue' in value) return 'reference';
  if ('geoPointValue' in value) return 'geopoint';
  if ('mapValue' in value) return 'map';
  if ('arrayValue' in value) return 'array';
  return 'unknown';
}

function normalizeUnsafeInteger(rawValue, integerOverflowMode) {
  const asBigInt = BigInt(rawValue);
  if (asBigInt <= SAFE_INT_MAX && asBigInt >= SAFE_INT_MIN) {
    return Number(rawValue);
  }
  if (integerOverflowMode === 'number') {
    return Number(rawValue);
  }
  return rawValue;
}

function decodeFirestoreValue(value, integerOverflowMode) {
  const kind = firestoreValueKind(value);

  switch (kind) {
    case 'null':
      return null;
    case 'boolean':
      return value.booleanValue;
    case 'integer':
      return normalizeUnsafeInteger(value.integerValue, integerOverflowMode);
    case 'double':
      return Number(value.doubleValue);
    case 'timestamp':
      return new Date(value.timestampValue).toISOString();
    case 'string':
      return value.stringValue;
    case 'bytes':
      return value.bytesValue;
    case 'reference':
      return value.referenceValue;
    case 'geopoint':
      return {
        latitude: Number(value.geoPointValue.latitude),
        longitude: Number(value.geoPointValue.longitude),
      };
    case 'array':
      return (value.arrayValue.values ?? []).map((entry) => decodeFirestoreValue(entry, integerOverflowMode));
    case 'map':
      return decodeFirestoreFields(value.mapValue.fields ?? {}, integerOverflowMode);
    default:
      return value;
  }
}

function decodeFirestoreFields(fields, integerOverflowMode) {
  const decoded = {};
  for (const [fieldName, fieldValue] of Object.entries(fields)) {
    decoded[fieldName] = decodeFirestoreValue(fieldValue, integerOverflowMode);
  }
  return decoded;
}

function inferScalarPreview(rawValue) {
  const kind = firestoreValueKind(rawValue);
  switch (kind) {
    case 'null':
      return null;
    case 'boolean':
      return rawValue.booleanValue;
    case 'integer':
      return rawValue.integerValue;
    case 'double':
      return rawValue.doubleValue;
    case 'timestamp':
      return rawValue.timestampValue;
    case 'string':
      return rawValue.stringValue;
    case 'bytes':
      return `<bytes:${String(rawValue.bytesValue ?? '').length}>`;
    case 'reference':
      return rawValue.referenceValue;
    case 'geopoint':
      return `${rawValue.geoPointValue.latitude},${rawValue.geoPointValue.longitude}`;
    case 'array':
      return `<array:${(rawValue.arrayValue.values ?? []).length}>`;
    case 'map':
      return `<map:${Object.keys(rawValue.mapValue.fields ?? {}).length}>`;
    default:
      return '<unknown>';
  }
}

function createFieldStat() {
  return {
    presentInDocuments: 0,
    kinds: {},
    nullCount: 0,
    numericMin: null,
    numericMax: null,
    stringMinLength: null,
    stringMaxLength: null,
    arrayMinLength: null,
    arrayMaxLength: null,
    sampleValues: [],
    sampleValueSet: new Set(),
  };
}

function createCollectionAccumulator(pathPattern, collectionId) {
  return {
    pathPattern,
    collectionId,
    documentCount: 0,
    sampleDocumentIds: [],
    sampleDocumentPaths: [],
    fieldStats: new Map(),
    repeatedShapeCounts: new Map(),
    subcollectionPatterns: new Set(),
    timestampFieldCounts: new Map(),
  };
}

function bumpCounter(record, key) {
  record[key] = (record[key] ?? 0) + 1;
}

function bumpMapCounter(counterMap, key) {
  counterMap.set(key, (counterMap.get(key) ?? 0) + 1);
}

function recordFieldPresence(fieldStats, fieldPath) {
  if (!fieldStats.has(fieldPath)) {
    fieldStats.set(fieldPath, createFieldStat());
  }
  fieldStats.get(fieldPath).presentInDocuments += 1;
}

function updateSamples(stat, rawValue) {
  if (stat.sampleValues.length >= 12) {
    return;
  }
  const preview = inferScalarPreview(rawValue);
  const serialized = JSON.stringify(preview);
  if (!stat.sampleValueSet.has(serialized)) {
    stat.sampleValueSet.add(serialized);
    stat.sampleValues.push(preview);
  }
}

function updateNumericRange(stat, candidate) {
  if (!Number.isFinite(candidate)) {
    return;
  }
  stat.numericMin = stat.numericMin === null ? candidate : Math.min(stat.numericMin, candidate);
  stat.numericMax = stat.numericMax === null ? candidate : Math.max(stat.numericMax, candidate);
}

function updateLengthRange(stat, propertyNameMin, propertyNameMax, length) {
  stat[propertyNameMin] = stat[propertyNameMin] === null ? length : Math.min(stat[propertyNameMin], length);
  stat[propertyNameMax] = stat[propertyNameMax] === null ? length : Math.max(stat[propertyNameMax], length);
}

function walkRawFields(rawFields, fieldStats, fieldPathPrefix = '') {
  for (const [fieldName, rawValue] of Object.entries(rawFields)) {
    const fieldPath = fieldPathPrefix ? `${fieldPathPrefix}.${fieldName}` : fieldName;
    recordFieldPresence(fieldStats, fieldPath);
    const stat = fieldStats.get(fieldPath);
    const kind = firestoreValueKind(rawValue);
    bumpCounter(stat.kinds, kind);
    updateSamples(stat, rawValue);

    if (kind === 'null') {
      stat.nullCount += 1;
      continue;
    }

    if (kind === 'integer') {
      try {
        updateNumericRange(stat, Number(rawValue.integerValue));
      } catch {
        // Keep sample only.
      }
      continue;
    }

    if (kind === 'double') {
      updateNumericRange(stat, Number(rawValue.doubleValue));
      continue;
    }

    if (kind === 'string' || kind === 'timestamp' || kind === 'reference' || kind === 'bytes') {
      const length = String(inferScalarPreview(rawValue) ?? '').length;
      updateLengthRange(stat, 'stringMinLength', 'stringMaxLength', length);
      continue;
    }

    if (kind === 'array') {
      const values = rawValue.arrayValue.values ?? [];
      updateLengthRange(stat, 'arrayMinLength', 'arrayMaxLength', values.length);
      for (const entry of values) {
        const arrayPath = `${fieldPath}[]`;
        recordFieldPresence(fieldStats, arrayPath);
        const arrayStat = fieldStats.get(arrayPath);
        const itemKind = firestoreValueKind(entry);
        bumpCounter(arrayStat.kinds, itemKind);
        updateSamples(arrayStat, entry);

        if (itemKind === 'map') {
          walkRawFields(entry.mapValue.fields ?? {}, fieldStats, arrayPath);
        } else if (itemKind === 'array') {
          walkRawFields({ value: entry }, fieldStats, arrayPath);
        }
      }
      continue;
    }

    if (kind === 'map') {
      walkRawFields(rawValue.mapValue.fields ?? {}, fieldStats, fieldPath);
    }
  }
}

function buildShapeSignatureFromFields(rawFields) {
  const entries = Object.entries(rawFields).map(([fieldName, rawValue]) => {
    const kind = firestoreValueKind(rawValue);
    if (kind === 'map') {
      return `${fieldName}:{${buildShapeSignatureFromFields(rawValue.mapValue.fields ?? {})}}`;
    }
    if (kind === 'array') {
      const itemKinds = (rawValue.arrayValue.values ?? []).map((item) => firestoreValueKind(item)).sort();
      return `${fieldName}:[${itemKinds.join('|')}]`;
    }
    return `${fieldName}:${kind}`;
  });
  return entries.sort().join(',');
}

function resolveCollectionPattern(collectionPath) {
  const segments = String(collectionPath).split('/').filter(Boolean);
  return segments.map((segment, index) => (index % 2 === 1 ? '{documentId}' : segment)).join('/');
}

function tryParseIsoDate(value) {
  if (typeof value !== 'string') {
    return null;
  }
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

function extractDocumentDateInfo(decodedFields, baselineMonthDay) {
  const parseMonthDay = (date) => `${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`;

  for (const fieldName of DATE_FIELD_PRIORITY) {
    const parsed = tryParseIsoDate(decodedFields[fieldName]);
    if (parsed) {
      return {
        field: fieldName,
        iso: parsed.toISOString(),
        matchesBaseline: parseMonthDay(parsed) === baselineMonthDay,
      };
    }
  }

  for (const [fieldName, value] of Object.entries(decodedFields)) {
    const parsed = tryParseIsoDate(value);
    if (parsed) {
      return {
        field: fieldName,
        iso: parsed.toISOString(),
        matchesBaseline: parseMonthDay(parsed) === baselineMonthDay,
      };
    }
  }

  return null;
}

function registerDocumentSchema(accumulatorMap, collectionPath, documentId, documentPath, rawFields, subcollectionPaths, dateInfo = null) {
  const collectionPattern = resolveCollectionPattern(collectionPath);
  const collectionId = collectionPath.split('/').filter(Boolean).at(-1);
  if (!accumulatorMap.has(collectionPattern)) {
    accumulatorMap.set(collectionPattern, createCollectionAccumulator(collectionPattern, collectionId));
  }

  const accumulator = accumulatorMap.get(collectionPattern);
  accumulator.documentCount += 1;
  if (accumulator.sampleDocumentIds.length < 25) {
    accumulator.sampleDocumentIds.push(documentId);
  }
  if (accumulator.sampleDocumentPaths.length < 25) {
    accumulator.sampleDocumentPaths.push(documentPath);
  }

  walkRawFields(rawFields, accumulator.fieldStats);
  const shapeSignature = buildShapeSignatureFromFields(rawFields);
  accumulator.repeatedShapeCounts.set(shapeSignature, (accumulator.repeatedShapeCounts.get(shapeSignature) ?? 0) + 1);

  for (const childCollectionPath of subcollectionPaths) {
    accumulator.subcollectionPatterns.add(resolveCollectionPattern(childCollectionPath));
  }

  if (dateInfo?.field) {
    bumpMapCounter(accumulator.timestampFieldCounts, dateInfo.field);
  }
}

function createShapeNode() {
  return {
    kindCounts: new Map(),
    children: new Map(),
    arrayItem: null,
  };
}

function jsKind(value) {
  if (value === null) return 'null';
  if (Array.isArray(value)) return 'array';
  if (typeof value === 'boolean') return 'boolean';
  if (typeof value === 'number') return 'number';
  if (typeof value === 'string') return 'string';
  if (typeof value === 'object') return 'map';
  return 'unknown';
}

function mergeValueIntoShape(node, value) {
  const kind = jsKind(value);
  bumpMapCounter(node.kindCounts, kind);

  if (kind === 'map') {
    for (const [fieldName, nestedValue] of Object.entries(value)) {
      if (!node.children.has(fieldName)) {
        node.children.set(fieldName, createShapeNode());
      }
      mergeValueIntoShape(node.children.get(fieldName), nestedValue);
    }
    return;
  }

  if (kind === 'array') {
    if (!node.arrayItem) {
      node.arrayItem = createShapeNode();
    }
    for (const item of value) {
      mergeValueIntoShape(node.arrayItem, item);
    }
  }
}

function dominantShapeKind(node) {
  const entries = [...node.kindCounts.entries()];
  if (entries.length === 0) {
    return 'null';
  }
  entries.sort((left, right) => right[1] - left[1]);
  const kindsByPriority = ['map', 'array', 'string', 'number', 'boolean', 'null', 'unknown'];
  entries.sort((left, right) => {
    if (right[1] !== left[1]) {
      return right[1] - left[1];
    }
    return kindsByPriority.indexOf(left[0]) - kindsByPriority.indexOf(right[0]);
  });
  return entries[0][0];
}

function defaultValueFromShape(node) {
  const dominantKind = dominantShapeKind(node);
  if (dominantKind === 'map') {
    const output = {};
    for (const [fieldName, childNode] of [...node.children.entries()].sort((left, right) => left[0].localeCompare(right[0]))) {
      output[fieldName] = defaultValueFromShape(childNode);
    }
    return output;
  }
  if (dominantKind === 'array') {
    return [];
  }
  return null;
}

function normalizeValueWithShape(value, node) {
  if (!node) {
    return value;
  }

  if (value === undefined) {
    return defaultValueFromShape(node);
  }

  const kind = jsKind(value);
  if (kind === 'map') {
    const output = { ...value };
    for (const [fieldName, childNode] of node.children.entries()) {
      output[fieldName] = normalizeValueWithShape(output[fieldName], childNode);
    }
    return output;
  }

  if (kind === 'array' && node.arrayItem) {
    return value.map((item) => normalizeValueWithShape(item, node.arrayItem));
  }

  return value;
}

function cloneValue(value) {
  return JSON.parse(JSON.stringify(value));
}

function finalizeFieldStats(fieldStats, documentCount) {
  const fields = {};
  for (const [fieldPath, stat] of [...fieldStats.entries()].sort((left, right) => left[0].localeCompare(right[0]))) {
    const kindEntries = Object.entries(stat.kinds).sort((left, right) => left[0].localeCompare(right[0]));
    fields[fieldPath] = {
      required: stat.presentInDocuments === documentCount && documentCount > 0,
      optional: stat.presentInDocuments !== documentCount,
      presenceRatio: documentCount === 0 ? 0 : Number((stat.presentInDocuments / documentCount).toFixed(4)),
      presentInDocuments: stat.presentInDocuments,
      nullCount: stat.nullCount,
      kinds: Object.fromEntries(kindEntries),
      constraints: {
        ...(stat.numericMin !== null && stat.numericMax !== null
          ? { numericRange: { min: stat.numericMin, max: stat.numericMax } }
          : {}),
        ...(stat.stringMinLength !== null && stat.stringMaxLength !== null
          ? { stringLengthRange: { min: stat.stringMinLength, max: stat.stringMaxLength } }
          : {}),
        ...(stat.arrayMinLength !== null && stat.arrayMaxLength !== null
          ? { arrayLengthRange: { min: stat.arrayMinLength, max: stat.arrayMaxLength } }
          : {}),
      },
      sampleValues: stat.sampleValues,
    };
  }
  return fields;
}

function finalizeSchema(fullAccumulators, baselineAccumulators, baselineShapes, baselineMonthDay, baselineTimezone) {
  const allPatterns = [...new Set([
    ...fullAccumulators.keys(),
    ...baselineAccumulators.keys(),
  ])].sort((left, right) => left.localeCompare(right));

  const collections = {};
  for (const pathPattern of allPatterns) {
    const fullAccumulator = fullAccumulators.get(pathPattern) ?? createCollectionAccumulator(pathPattern, pathPattern.split('/').at(-1));
    const baselineAccumulator = baselineAccumulators.get(pathPattern) ?? createCollectionAccumulator(pathPattern, fullAccumulator.collectionId);
    const repeatedShapes = [...fullAccumulator.repeatedShapeCounts.entries()]
      .sort((left, right) => right[1] - left[1])
      .slice(0, 10)
      .map(([signature, occurrences]) => ({ occurrences, signature }));

    collections[pathPattern] = {
      collectionId: fullAccumulator.collectionId,
      pathPattern,
      documentCount: fullAccumulator.documentCount,
      baselineDocumentCount: baselineAccumulator.documentCount,
      baselineMonthDay,
      baselineTimezone,
      baselineAvailable: baselineAccumulator.documentCount > 0,
      sampleDocumentIds: fullAccumulator.sampleDocumentIds,
      sampleDocumentPaths: fullAccumulator.sampleDocumentPaths,
      subcollectionPatterns: [...fullAccumulator.subcollectionPatterns].sort(),
      repeatedStructures: repeatedShapes,
      timestampFieldsObserved: Object.fromEntries(
        [...fullAccumulator.timestampFieldCounts.entries()].sort((left, right) => right[1] - left[1]),
      ),
      baselineTimestampFieldsObserved: Object.fromEntries(
        [...baselineAccumulator.timestampFieldCounts.entries()].sort((left, right) => right[1] - left[1]),
      ),
      fields: {
        full: finalizeFieldStats(fullAccumulator.fieldStats, fullAccumulator.documentCount),
        baseline: finalizeFieldStats(baselineAccumulator.fieldStats, baselineAccumulator.documentCount),
      },
      normalization: {
        addsBaselineFieldsFromUnion: baselineAccumulator.documentCount > 0,
        defaultScalarFill: null,
        defaultArrayFill: [],
        defaultMapFill: 'recursive object with baseline keys',
      },
      baselineShapeSummary: summarizeShapeNode(baselineShapes.get(pathPattern) ?? createShapeNode()),
    };
  }

  return collections;
}

function summarizeShapeNode(node) {
  return {
    dominantKind: dominantShapeKind(node),
    kindCounts: Object.fromEntries([...node.kindCounts.entries()].sort((left, right) => left[0].localeCompare(right[0]))),
    children: Object.fromEntries(
      [...node.children.entries()]
        .sort((left, right) => left[0].localeCompare(right[0]))
        .map(([key, child]) => [key, summarizeShapeNode(child)]),
    ),
    arrayItem: node.arrayItem ? summarizeShapeNode(node.arrayItem) : null,
  };
}

function normalizeCollectionTree(decodedTree, baselineShapes, collectionPath) {
  const normalizedTree = {};
  const collectionPattern = resolveCollectionPattern(collectionPath);
  const collectionShape = baselineShapes.get(collectionPattern) ?? null;

  for (const [documentId, payload] of Object.entries(decodedTree)) {
    const normalizedData = collectionShape
      ? normalizeValueWithShape(payload.data, collectionShape)
      : cloneValue(payload.data);

    const normalizedSubcollections = {};
    for (const [subcollectionId, subcollectionTree] of Object.entries(payload.subcollections ?? {})) {
      normalizedSubcollections[subcollectionId] = normalizeCollectionTree(
        subcollectionTree,
        baselineShapes,
        `${payload.__path}/${subcollectionId}`,
      );
    }

    normalizedTree[documentId] = {
      __path: payload.__path,
      data: normalizedData,
      dateInfo: payload.dateInfo,
      ...(Object.keys(normalizedSubcollections).length > 0 ? { subcollections: normalizedSubcollections } : {}),
    };
  }

  return normalizedTree;
}

function convertNormalizedTreeToRealtimeTree(normalizedTree) {
  const rtdbTree = {};

  for (const [documentId, payload] of Object.entries(normalizedTree)) {
    const rtdbDocument = cloneValue(payload.data);
    if (payload.subcollections && Object.keys(payload.subcollections).length > 0) {
      rtdbDocument.__subcollections = {};
      for (const [subcollectionId, subcollectionTree] of Object.entries(payload.subcollections)) {
        rtdbDocument.__subcollections[subcollectionId] = convertNormalizedTreeToRealtimeTree(subcollectionTree);
      }
    }
    rtdbTree[documentId] = rtdbDocument;
  }

  return rtdbTree;
}

function summarizeRawExport(rawCollections) {
  let totalDocuments = 0;
  let totalCollections = 0;

  function walkCollectionTree(collectionNode) {
    totalCollections += 1;
    for (const document of Object.values(collectionNode)) {
      totalDocuments += 1;
      const subcollections = document.subcollections ?? {};
      for (const nestedCollection of Object.values(subcollections)) {
        walkCollectionTree(nestedCollection);
      }
    }
  }

  for (const collectionNode of Object.values(rawCollections)) {
    walkCollectionTree(collectionNode);
  }

  return { totalDocuments, totalCollections };
}

function summarizeBaselineUsage(normalizedCollections) {
  let baselineDocuments = 0;
  let collectionsWithBaseline = 0;

  function walk(collectionNode) {
    for (const document of Object.values(collectionNode)) {
      if (document.dateInfo?.matchesBaseline) {
        baselineDocuments += 1;
      }
      for (const nested of Object.values(document.subcollections ?? {})) {
        walk(nested);
      }
    }
  }

  for (const collectionNode of Object.values(normalizedCollections)) {
    walk(collectionNode);
  }

  return { baselineDocuments, collectionsWithBaseline };
}

async function exportCollectionTree(context, collectionPath, fullAccumulators, baselineAccumulators, baselineShapes) {
  const documents = await listDocuments(
    context.sourceProjectId,
    context.databaseId,
    context.accessToken,
    collectionPath,
    context.batchSize,
  );

  const rawTree = {};
  const decodedTree = {};

  for (const document of documents) {
    const documentPath = extractRelativeDocumentPath(context.sourceProjectId, context.databaseId, document.name);
    const documentId = documentPath.split('/').at(-1);
    const rawFields = document.fields ?? {};
    const decodedFields = decodeFirestoreFields(rawFields, context.integerOverflowMode);
    const dateInfo = extractDocumentDateInfo(decodedFields, context.baselineMonthDay);
    const subcollectionIds = await listCollectionIds(
      context.sourceProjectId,
      context.databaseId,
      context.accessToken,
      documentPath,
      context.batchSize,
    );

    const rawSubcollections = {};
    const decodedSubcollections = {};
    const subcollectionPaths = [];

    for (const subcollectionId of subcollectionIds) {
      const childCollectionPath = `${documentPath}/${subcollectionId}`;
      subcollectionPaths.push(childCollectionPath);
      const childTree = await exportCollectionTree(
        context,
        childCollectionPath,
        fullAccumulators,
        baselineAccumulators,
        baselineShapes,
      );
      rawSubcollections[subcollectionId] = childTree.rawTree;
      decodedSubcollections[subcollectionId] = childTree.decodedTree;
    }

    registerDocumentSchema(fullAccumulators, collectionPath, documentId, documentPath, rawFields, subcollectionPaths, dateInfo);

    if (dateInfo?.matchesBaseline) {
      registerDocumentSchema(baselineAccumulators, collectionPath, documentId, documentPath, rawFields, subcollectionPaths, dateInfo);
      const collectionPattern = resolveCollectionPattern(collectionPath);
      if (!baselineShapes.has(collectionPattern)) {
        baselineShapes.set(collectionPattern, createShapeNode());
      }
      mergeValueIntoShape(baselineShapes.get(collectionPattern), decodedFields);
    }

    rawTree[documentId] = {
      __path: documentPath,
      fields: rawFields,
      ...(Object.keys(rawSubcollections).length > 0 ? { subcollections: rawSubcollections } : {}),
    };

    decodedTree[documentId] = {
      __path: documentPath,
      data: decodedFields,
      dateInfo,
      ...(Object.keys(decodedSubcollections).length > 0 ? { subcollections: decodedSubcollections } : {}),
    };
  }

  return { rawTree, decodedTree };
}

async function tryResolveSourceProject(context, sourceProjectCandidates, accessibleProjects) {
  const orderedCandidates = [
    ...sourceProjectCandidates,
    ...accessibleProjects.filter((projectId) => !sourceProjectCandidates.includes(projectId)),
  ];

  for (const projectId of orderedCandidates) {
    try {
      const topLevelCollections = await listCollectionIds(projectId, context.databaseId, context.accessToken, '', context.batchSize);
      return { projectId, topLevelCollections };
    } catch (error) {
      if (error.status === 403 || error.status === 404) {
        context.projectResolutionErrors.push({
          projectId,
          status: error.status,
          message: error.message,
        });
        continue;
      }
      throw error;
    }
  }

  throw new Error(
    `Unable to access any candidate Firestore project. Tried: ${orderedCandidates.join(', ') || '<none>'}`,
  );
}

function buildExportMetadata(runtime) {
  return {
    generatedAt: new Date().toISOString(),
    sourceProjectId: runtime.sourceProjectId,
    requestedSourceProjectId: runtime.requestedSourceProjectId,
    databaseId: runtime.databaseId,
    targetProjectId: runtime.targetProjectId,
    targetDatabaseUrl: runtime.targetDatabaseUrl,
    authType: runtime.auth.type,
    sourceProjectCandidates: runtime.sourceProjectCandidates,
    accessibleProjectsViaCli: runtime.accessibleProjectsViaCli,
    baselineMonthDay: runtime.baselineMonthDay,
    baselineTimezone: runtime.baselineTimezone,
    warnings: runtime.warnings,
    projectResolutionErrors: runtime.projectResolutionErrors,
  };
}

function buildRealtimePayload(realtimeCollections) {
  return realtimeCollections;
}

function buildCliCommands(runtime, outputPaths) {
  const commands = [];
  const importPath = runtime.importPath || '/';
  commands.push('# 1. Authenticate the Firebase CLI');
  commands.push('firebase login');
  commands.push('');
  commands.push('# 2. List projects to verify access');
  commands.push('firebase projects:list');
  commands.push('');
  commands.push('# 3. Try the requested source project first');
  commands.push(`firebase use ${runtime.requestedSourceProjectId}`);
  commands.push('');
  if (runtime.sourceProjectId && runtime.sourceProjectId !== runtime.requestedSourceProjectId) {
    commands.push('# 4. Fallback to the accessible source project resolved by the migration tool');
    commands.push(`firebase use ${runtime.sourceProjectId}`);
    commands.push('');
  } else {
    commands.push('# 4. Source project is accessible; keep that CLI context');
    commands.push(`# firebase use ${runtime.sourceProjectId}`);
    commands.push('');
  }
  commands.push('# 5. Run the full export + baseline normalization + transform step');
  commands.push([
    'node scripts/firestore_to_rtdb_migration.mjs',
    `--source-project-id ${runtime.requestedSourceProjectId}`,
    runtime.sourceProjectCandidates.length > 1
      ? `--source-candidates ${runtime.sourceProjectCandidates.filter((item) => item !== runtime.requestedSourceProjectId).join(',')}`
      : null,
    `--baseline-month-day ${runtime.baselineMonthDay}`,
    runtime.targetProjectId ? `--target-project-id ${runtime.targetProjectId}` : null,
    runtime.targetDatabaseUrl ? `--target-database-url ${runtime.targetDatabaseUrl}` : null,
    runtime.serviceAccountPath ? `--service-account "${runtime.serviceAccountPath}"` : null,
    `--out-dir "${path.relative(process.cwd(), runtime.outDir) || runtime.outDir}"`,
  ].filter(Boolean).join(' '));
  commands.push('');
  if (runtime.targetProjectId) {
    commands.push('# 6. Optional interactive CLI import');
    commands.push(`firebase database:set ${importPath} "${outputPaths.realtime}" --project ${runtime.targetProjectId}`);
    commands.push('');
    commands.push('# 6b. Noninteractive import through the migration tool REST path');
    commands.push([
      'node scripts/firestore_to_rtdb_migration.mjs',
      `--source-project-id ${runtime.requestedSourceProjectId}`,
      runtime.sourceProjectCandidates.length > 1
        ? `--source-candidates ${runtime.sourceProjectCandidates.filter((item) => item !== runtime.requestedSourceProjectId).join(',')}`
        : null,
      `--baseline-month-day ${runtime.baselineMonthDay}`,
      runtime.targetProjectId ? `--target-project-id ${runtime.targetProjectId}` : null,
      runtime.targetDatabaseUrl ? `--target-database-url ${runtime.targetDatabaseUrl}` : null,
      runtime.serviceAccountPath ? `--service-account "${runtime.serviceAccountPath}"` : null,
      `--out-dir "${path.relative(process.cwd(), runtime.outDir) || runtime.outDir}"`,
      '--import-method rest',
      '--execute-import',
    ].filter(Boolean).join(' '));
    commands.push('');
  }
  commands.push('# 7. Optional live mirror from Firestore to Realtime Database');
  commands.push([
    'node scripts/firestore_to_rtdb_sync.mjs',
    `--source-project-id ${runtime.sourceProjectId}`,
    runtime.targetDatabaseUrl ? `--target-database-url ${runtime.targetDatabaseUrl}` : null,
    runtime.serviceAccountPath ? `--service-account "${runtime.serviceAccountPath}"` : null,
    '--verbose',
  ].filter(Boolean).join(' '));
  commands.push('');
  return commands.join('\n');
}

async function importRealtimeDatabaseViaCli(firebaseBinary, projectId, importPath, payloadPath) {
  const result = await runCommand(firebaseBinary, ['database:set', importPath, payloadPath, '--project', projectId, '--confirm']);
  if (result.code !== 0) {
    throw new Error(`firebase database:set failed: ${result.stderr || result.stdout}`);
  }
}

async function importRealtimeDatabaseViaRest(databaseUrl, importPath, payload, accessToken) {
  const normalizedPath = importPath === '/' ? '' : importPath.replace(/^\/+|\/+$/g, '');
  const targetUrl = `${databaseUrl.replace(/\/+$/, '')}/${normalizedPath ? `${normalizedPath}/` : ''}.json?print=silent`;
  const response = await fetch(targetUrl, {
    method: 'PUT',
    headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Realtime Database REST import failed (${response.status}): ${details}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    return;
  }

  const cwd = process.cwd();
  const localContext = await loadLocalProjectContext(cwd);
  const auth = await resolveAuth(args);
  if (!auth) {
    throw new Error(
      'No usable credentials were found. Use --service-account, set GOOGLE_APPLICATION_CREDENTIALS, or run firebase login before retrying.',
    );
  }

  const firebaseBinary = await findFirebaseCliBinary(cwd);
  const accessibleProjectsViaCli = await listAccessibleFirebaseProjects(firebaseBinary, cwd);
  const sourceProjectCandidates = resolveSourceProjectCandidates(args, localContext, auth);
  const targetProjectId = resolveTargetProjectId(args, localContext, accessibleProjectsViaCli);
  const targetDatabaseUrl = resolveTargetDatabaseUrl(args, localContext, targetProjectId);
  const outDir = path.resolve(cwd, args.outDir);

  const runtime = {
    requestedSourceProjectId: args.sourceProjectId,
    sourceProjectCandidates,
    accessibleProjectsViaCli,
    databaseId: args.databaseId,
    targetProjectId,
    targetDatabaseUrl,
    accessToken: auth.accessToken,
    auth,
    outDir,
    batchSize: args.batchSize,
    importPath: args.importPath,
    integerOverflowMode: args.integerOverflowMode,
    serviceAccountPath: args.serviceAccount ? path.resolve(cwd, args.serviceAccount) : null,
    baselineMonthDay: args.baselineMonthDay,
    baselineTimezone: args.baselineTimezone,
    warnings: [],
    projectResolutionErrors: [],
  };

  const projectResolution = await tryResolveSourceProject(runtime, sourceProjectCandidates, accessibleProjectsViaCli);
  runtime.sourceProjectId = projectResolution.projectId;
  runtime.topLevelCollections = projectResolution.topLevelCollections;

  if (firebaseBinary && args.cliProjectSwitch) {
    const switched = await switchFirebaseCliProject(firebaseBinary, runtime.sourceProjectId, cwd);
    if (!switched) {
      runtime.warnings.push(`Unable to switch local Firebase CLI context to ${runtime.sourceProjectId}.`);
    }
  }

  if (args.dryRun) {
    console.log(jsonStringify({
      metadata: buildExportMetadata(runtime),
      dryRun: true,
      topLevelCollections: runtime.topLevelCollections,
    }, args.pretty));
    return;
  }

  const fullAccumulators = new Map();
  const baselineAccumulators = new Map();
  const baselineShapes = new Map();
  const rawCollections = {};
  const decodedCollections = {};

  for (const collectionId of runtime.topLevelCollections) {
    const exported = await exportCollectionTree(
      runtime,
      collectionId,
      fullAccumulators,
      baselineAccumulators,
      baselineShapes,
    );
    rawCollections[collectionId] = exported.rawTree;
    decodedCollections[collectionId] = exported.decodedTree;
  }

  const normalizedCollections = {};
  const realtimeCollections = {};
  for (const [collectionId, decodedTree] of Object.entries(decodedCollections)) {
    const normalizedTree = normalizeCollectionTree(decodedTree, baselineShapes, collectionId);
    normalizedCollections[collectionId] = normalizedTree;
    realtimeCollections[collectionId] = convertNormalizedTreeToRealtimeTree(normalizedTree);
  }

  const exportSummary = summarizeRawExport(rawCollections);
  const baselineSummary = summarizeBaselineUsage(normalizedCollections);
  const collectionsWithBaseline = [...baselineAccumulators.values()].filter((item) => item.documentCount > 0).length;
  baselineSummary.collectionsWithBaseline = collectionsWithBaseline;
  const exportMetadata = buildExportMetadata(runtime);

  const schema = {
    metadata: {
      ...exportMetadata,
      ...exportSummary,
      ...baselineSummary,
    },
    collections: finalizeSchema(
      fullAccumulators,
      baselineAccumulators,
      baselineShapes,
      runtime.baselineMonthDay,
      runtime.baselineTimezone,
    ),
  };

  const firestoreFullExport = {
    metadata: {
      ...exportMetadata,
      ...exportSummary,
      ...baselineSummary,
    },
    collections: rawCollections,
  };

  const normalizedFirestore = {
    metadata: {
      ...exportMetadata,
      ...exportSummary,
      ...baselineSummary,
    },
    collections: normalizedCollections,
  };

  const realtimeDbReady = buildRealtimePayload(realtimeCollections);

  const outputPaths = {
    firestoreFull: path.join(outDir, 'firestore_full_export.json'),
    schema: path.join(outDir, 'firestore_schema.json'),
    normalized: path.join(outDir, 'normalized_firestore.json'),
    realtime: path.join(outDir, 'realtime_db_ready.json'),
    commands: path.join(outDir, 'firebase_cli_commands.txt'),
  };

  await writeJson(outputPaths.firestoreFull, firestoreFullExport, args.pretty);
  await writeJson(outputPaths.schema, schema, args.pretty);
  await writeJson(outputPaths.normalized, normalizedFirestore, args.pretty);
  await writeJson(outputPaths.realtime, realtimeDbReady, args.pretty);

  if (args.writeCliCommands) {
    await writeText(outputPaths.commands, buildCliCommands(runtime, outputPaths));
  }

  if (args.executeImport) {
    if (args.importMethod === 'cli') {
      if (!firebaseBinary) {
        throw new Error('Firebase CLI is not available for --import-method cli.');
      }
      if (!runtime.targetProjectId) {
        throw new Error('Target project id is required for --import-method cli.');
      }
      await importRealtimeDatabaseViaCli(firebaseBinary, runtime.targetProjectId, args.importPath, outputPaths.realtime);
    } else if (args.importMethod === 'rest') {
      if (!runtime.targetDatabaseUrl) {
        throw new Error('Target database URL is required for --import-method rest.');
      }
      await importRealtimeDatabaseViaRest(
        runtime.targetDatabaseUrl,
        args.importPath,
        realtimeDbReady,
        runtime.accessToken,
      );
    } else {
      runtime.warnings.push('Import was requested, but --import-method none prevents execution.');
    }
  }

  console.log(jsonStringify({
    ok: true,
    sourceProjectId: runtime.sourceProjectId,
    targetProjectId: runtime.targetProjectId,
    topLevelCollections: runtime.topLevelCollections,
    outputPaths,
    summary: {
      ...exportSummary,
      ...baselineSummary,
    },
    warnings: runtime.warnings,
  }, args.pretty));
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
