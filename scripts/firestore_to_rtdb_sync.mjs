#!/usr/bin/env node

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

import { cert, initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

function parseArgs(argv) {
  const args = {
    sourceProjectId: 'scadadataserver',
    targetDatabaseUrl: process.env.FIREBASE_DATABASE_URL || 'https://scadadataserver-default-rtdb.firebaseio.com',
    serviceAccount: process.env.FIREBASE_SERVICE_ACCOUNT_JSON || process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
    verbose: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) {
      continue;
    }

    const [key, inlineValue] = token.slice(2).split('=', 2);
    const nextValue = inlineValue ?? argv[index + 1];
    const consumeNext = inlineValue === undefined;

    switch (key) {
      case 'source-project-id':
        args.sourceProjectId = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'target-database-url':
        args.targetDatabaseUrl = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'service-account':
        args.serviceAccount = nextValue;
        if (consumeNext) index += 1;
        break;
      case 'verbose':
        args.verbose = true;
        break;
      default:
        throw new Error(`Unknown argument: --${key}`);
    }
  }

  if (!args.serviceAccount) {
    throw new Error('A service account is required for the live sync script.');
  }

  if (!args.targetDatabaseUrl) {
    throw new Error('A target Realtime Database URL is required for the live sync script.');
  }

  return args;
}

async function loadServiceAccount(serviceAccountPath) {
  const absolutePath = path.isAbsolute(serviceAccountPath)
    ? serviceAccountPath
    : path.resolve(process.cwd(), serviceAccountPath);
  const content = await readFile(absolutePath, 'utf8');
  return JSON.parse(content);
}

function decodeFirestoreValue(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map((entry) => decodeFirestoreValue(entry));
  }
  if (value instanceof Uint8Array || Buffer.isBuffer(value)) {
    return Buffer.from(value).toString('base64');
  }
  if (typeof value === 'object') {
    const output = {};
    for (const [key, nested] of Object.entries(value)) {
      output[key] = decodeFirestoreValue(nested);
    }
    return output;
  }
  return value;
}

async function listSubcollections(documentRef) {
  return documentRef.listCollections();
}

function toRealtimeDocument(documentData, subcollections) {
  const payload = decodeFirestoreValue(documentData ?? {});
  if (Object.keys(subcollections).length > 0) {
    payload.__subcollections = subcollections;
  }
  return payload;
}

async function syncDocumentTree(documentRef, rtdbRef, watchers, verbose) {
  const documentPath = documentRef.path;
  if (watchers.has(documentPath)) {
    return;
  }

  watchers.set(documentPath, true);

  if (verbose) {
    console.log(`watching document children: ${documentPath}`);
  }

  const subcollections = await listSubcollections(documentRef);
  for (const subcollectionRef of subcollections) {
    await syncCollectionTree(subcollectionRef, rtdbRef.child('__subcollections').child(subcollectionRef.id), watchers, verbose);
  }
}

async function syncCollectionTree(collectionRef, rtdbRef, watchers, verbose) {
  const collectionPath = collectionRef.path;
  if (watchers.has(collectionPath)) {
    return;
  }

  if (verbose) {
    console.log(`watching collection: ${collectionPath}`);
  }

  const unsubscribe = collectionRef.onSnapshot(async (snapshot) => {
    for (const change of snapshot.docChanges()) {
      const targetRef = rtdbRef.child(change.doc.id);

      if (change.type === 'removed') {
        if (verbose) {
          console.log(`remove ${change.doc.ref.path}`);
        }
        await targetRef.remove();
        continue;
      }

      const subcollections = {};
      const childCollections = await listSubcollections(change.doc.ref);
      for (const subcollectionRef of childCollections) {
        subcollections[subcollectionRef.id] = {};
      }

      if (verbose) {
        console.log(`upsert ${change.doc.ref.path}`);
      }

      await targetRef.set(toRealtimeDocument(change.doc.data(), subcollections));
      await syncDocumentTree(change.doc.ref, targetRef, watchers, verbose);
    }
  }, (error) => {
    console.error(`Snapshot listener failed for ${collectionPath}: ${error.message}`);
  });

  watchers.set(collectionPath, unsubscribe);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const serviceAccount = await loadServiceAccount(args.serviceAccount);
  const app = initializeApp({
    credential: cert(serviceAccount),
    projectId: args.sourceProjectId || serviceAccount.project_id,
    databaseURL: args.targetDatabaseUrl,
  });

  const firestore = getFirestore(app);
  const database = getDatabase(app);
  const watchers = new Map();

  const topLevelCollections = await firestore.listCollections();
  for (const collectionRef of topLevelCollections) {
    await syncCollectionTree(collectionRef, database.ref(collectionRef.id), watchers, args.verbose);
  }

  console.log(`Live sync started for ${topLevelCollections.length} top-level collections.`);
  process.stdin.resume();
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
