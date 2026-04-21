# Offline-First Support Implementation Plan

This document outlines the architecture and execution plan for implementing Phase P2.6 (Offline-First Capabilities) in the DukaNest Shop Owner Flutter App. The implementation heavily relies on `hive_flutter` (for local NoSQL storage) and `connectivity_plus` (for network state detection), both of which are already present in `pubspec.yaml`.

## Problem Statement

Shop owners operating in warehouses, delivery zones, or areas with poor network coverage need the ability to seamlessly:
1. View critical dashboard data (products, recent orders, metrics) instantly without waiting on network calls.
2. Perform critical mutations (update order statuses, adjust stock levels) even when completely offline.
The system needs to transparently queue these actions and sync them back to the server as soon as the connection is restored without causing data conflicts.

## Proposed Changes

We will split the implementation into two distinct architectural layers: **Read (Caching)** and **Write (Offline Queue)**.

---

### Layer 1: Core Database & Caching (Read Support)

We will initialize `Hive` and register static type adapters for our critical models. This allows Riverpod providers to instantly serve cached data while silently fetching fresh data in the background.

#### [NEW] `lib/core/storage/local_db.dart`
- **Purpose:** Initialize Hive and open required boxes on app startup.
- Establish the following Hive boxes:
  - `tenant_settings_box`
  - `dashboard_stats_box` (15m expiry)
  - `products_box` (Manual/Pull refresh)
  - `orders_box` (30m expiry)
  - `customers_box` (1h expiry)
  
#### [MODIFY] `lib/main.dart`
- Inherit `await LocalDb.init()` before `runApp`.

#### [MODIFY] `lib/features/dashboard/providers/dashboard_provider.dart` (Example)
- Update Riverpod logic to:
  1. Immediately emit `AsyncData` from `dashboard_stats_box` (if present).
  2. Perform network request to `/api/v1/mobile/dashboard/overview`.
  3. On success: update `dashboard_stats_box` and re-emit `AsyncData`.
  4. On failure: fail silently if cache exists, otherwise emit `AsyncError`.

---

### Layer 2: Offline Action Queue (Write Support)

We will build an intercepted mutation layer that writes failed or offline changes into a specialized Hive queue, and automatically flushes the queue when `connectivity_plus` detects connection restoration.

#### [NEW] `lib/core/storage/models/offline_action.dart`
- Create a model to represent queued requests.
- **Fields:** `id` (UUID), `endpoint` (String), `method` (String - POST/PUT/PATCH), `payload` (Map/JSON), `createdAt` (DateTime), `retryCount` (int).

#### [NEW] `lib/core/sync/sync_manager.dart`
- **Purpose:** Central brain for offline logic.
- **Listen:** Subscribe to `Connectivity().onConnectivityChanged`.
- **Flush:** When restoring to Mobile/Wifi:
  1. Lock the queue in memory.
  2. Iterate through actions sequentially via the API Client.
  3. On 2xx success: Remove from `offline_actions_box`.
  4. On 4xx (client error): Log error, mark failed, remove from box (to prevent infinite loops).
  5. On 5xx/Timeout: Keep in box, increment `retryCount`.

#### [MODIFY] `lib/core/api/api_client.dart`
- Add an `enqueueIfOffline` wrapper for specific mutation calls (Order updates, Stock adjustments).
- If the phone is offline, the API client bypasses the Dio network request completely, writes the payload to `offline_actions_box`, and returns a simulated "Success" so the UI thinks the operation succeeded.

---

### Layer 3: UI & UX Indicators

The UI needs to inform the user when they are looking at queued data or are offline.

#### [NEW] `lib/shared/widgets/offline_banner.dart`
- A subtle red/orange banner that slides down at the top of the app when `connectivity_plus` reports `ConnectivityResult.none`.

#### [NEW] `lib/shared/widgets/pending_sync_indicator.dart`
- A small `Icon(Icons.cloud_upload_outlined)` or similar badge.
- When an order item checks the `offline_actions_box` and sees an action pending for its ID, it displays this indicator to show the user the action is queued securely.

## Verification Plan

### Automated Tests
- Unit Test `SyncManager`: Write mocked tests for `flushQueue` to ensure 4xx errors discard the task and 5xx errors retain it.
- Unit Test `api_client.dart`: Ensure `enqueueIfOffline` strictly writes to Hive instead of triggering Dio when offline.

### Manual Verification
1. **Cache Loading:** Kill the app. Turn off Wifi/Data on the emulator. Open the app. Verify the Dashboard and Orders load instantly with previous data.
2. **Action Queuing:** While offline, mark an order as "Shipped". Verify the UI updates to "Shipped" and shows the cloud indicator.
3. **Restoration Sync:** Turn Wifi/Data back on. Watch the console to verify `SyncManager` flushes the request to the network, and verify the cloud indicator vanishes.
