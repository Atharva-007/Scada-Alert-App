# Database Detailed Audit

- Generated: 2026-04-24T00:08:27.049Z
- Source project requested: scadadaralert
- Source project used: scadadataserver
- Baseline date: 01-26 (UTC)
- Firestore documents: 22
- Firestore collections: 7
- Global prepared-vs-live equality ignoring nulls: false
- Global null-only diffs: 56
- Global other diffs: 1

## alerts_active

- Firestore raw top-level docs: 5
- Firestore recursive docs: 5
- Realtime top-level docs: 5
- Baseline available: true
- Baseline docs: 5
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 8
- Other diffs: 0
- Baseline required fields: category, equipment, id, isAcknowledged, isActive, location, message, priority, raisedAt, severity, status, title
- Firestore document IDs: ALT001, ALT002, ALT003, ALT004, ALT005

## alerts_history

- Firestore raw top-level docs: 2
- Firestore recursive docs: 2
- Realtime top-level docs: 2
- Baseline available: false
- Baseline docs: 0
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 0
- Other diffs: 0
- Baseline required fields: none
- Firestore document IDs: ALT_H001, ALT_H002

## client_heartbeats

- Firestore raw top-level docs: 1
- Firestore recursive docs: 1
- Realtime top-level docs: 1
- Baseline available: false
- Baseline docs: 0
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 0
- Other diffs: 1
- Baseline required fields: none
- Firestore document IDs: windows_client

## config

- Firestore raw top-level docs: 1
- Firestore recursive docs: 1
- Realtime top-level docs: 1
- Baseline available: true
- Baseline docs: 1
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 0
- Other diffs: 0
- Baseline required fields: enableNotifications, heartbeatInterval, lastUpdated, maxOfflineQueueSize, notificationSound, offlineQueueEnabled, syncInterval
- Firestore document IDs: sync_settings

## device_tokens

- Firestore raw top-level docs: 7
- Firestore recursive docs: 7
- Realtime top-level docs: 7
- Baseline available: true
- Baseline docs: 1
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 0
- Other diffs: 0
- Baseline required fields: active, lastUpdated, platform, token
- Firestore document IDs: cUcJO0FTX1xp6i7b3wVMDE:APA91bEfclizJRmVAP-6fAYr7HMT1S9qEFlZuJ2oNRLiAdzQmzm2FbOJxze4kWRE9KXApJiCQ5U6pCeVSFRkb531sYconFAABMp9iNP9FstD7lPyVgovgw8, c_5fLdUbYCfQCXqpx7kudX:APA91bFF96MFEjmyv8RH1gPVFnxzpNIW8KEiQ7TwEXfXZwaucMpxovjLuwYB1baeQ7guhixNvCOjTS9YyRoBV2ukEZxNHHh0IvV4Nw66GynxOqctCi3sdqU, dJzN0STTRVubjUiJY312TZ:APA91bEcZamBFj9mGAimV8Hrig3nhNYAPBaPWJGL75HGl2MERJWIS9YVH2Sdh1FWr1TWP7ctWRDDbGL07mVtJpXJ1qWlubvSmAk8oXVZekD8suyu11wOFX0, dWuk3iKKfH_RQ8JzSzjDRj:APA91bHO9Bd5M3FSmT71Pv5nFVg-SN0zxrshrNEiBfK04uFyQ23x4m2MVgx480oVQ0yB7wvG88UTxQBCbQl-gLnuayfGXsOg4ASy0qAkE9H0ru1d3yuww4c, d_vHyuiuSDmK1yGTKW-_4a:APA91bHeIbZu2DATnoOvogNP9W2nim8Ie7XrbM_A73NX5m68OLnCeDZj0ME-54ThVi3nLvmctIDpQWc4fucnImiTQYUMSYPQVhidRZ8mCA4qxW2UyDL1P8g, dxkS7DOInZzRKpM24ZODEh:APA91bHnDCc3OA4u7FVR4ihI0_vnigbnVehPF17-rRCJlq3w_-MWLJSRrNpuogmI-t7fIWZd8xqMWlkCjyGjsdq0X2aJ5fprlVsSIGuO6nRayxCK2rTd8GQ, fnPDplJUdwW3P0ZwPO4f7H:APA91bEZTgY6Qnlv9bQA5tgYRl5bJVPJUdVcBcufez-U3DXWqSyFvo92zGS1upBn7yZGkvvxysXjpkc1jmLjKI5W8b9uNzhF8LKjNuVTKgr0jYvUpZRhq2Q

## statistics

- Firestore raw top-level docs: 1
- Firestore recursive docs: 1
- Realtime top-level docs: 1
- Baseline available: true
- Baseline docs: 1
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 0
- Other diffs: 0
- Baseline required fields: acknowledgedAlerts, criticalAlerts, lastUpdated, totalAlerts, totalCleared24h
- Firestore document IDs: overview

## system_status

- Firestore raw top-level docs: 5
- Firestore recursive docs: 5
- Realtime top-level docs: 5
- Baseline available: true
- Baseline docs: 4
- Missing in Realtime: none
- Extra in Realtime: none
- Null-only diffs: 48
- Other diffs: 0
- Baseline required fields: componentName, lastHeartbeat, metadata, status, version
- Firestore document IDs: Alert Engine, Database Server, Notification Service, OPC UA Server, Windows Sync Service

