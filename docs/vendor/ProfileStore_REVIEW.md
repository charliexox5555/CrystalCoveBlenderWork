# ProfileStore provenance and review

Official source: [MadStudioRoblox/ProfileStore](https://github.com/MadStudioRoblox/ProfileStore), commit `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31). The unmodified 2,243-line module is at `src/server/Vendor/ProfileStore.luau`. SHA-256: `AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F`. License: Apache 2.0, retained in `ProfileStore_LICENSE.txt`; the repository contains no NOTICE file.

Reviewed the complete module before integration: embedded signal implementation, serialized update queue, deep copies/reconciliation, session ownership/force-load handling, saves/end-session callbacks, mock stores, DataStore probe, messaging subscriptions, retries/backoff, version reads, auto-save and shutdown. No dynamic asset require, loadstring, getfenv, obfuscation or external HTTP request. HttpService is used for session GUIDs; DataStoreService and MessagingService handle storage/session coordination. The unused destructive RemoveAsync API is never exposed by the game.

Integration uses StartSessionAsync with cancellation, AddUserId, Reconcile, IsActive, OnSessionEnd and EndSession. Production cannot fall back to temporary player data after a failed load. Studio uses an isolated mock by default; it never writes player progress to production keys. ProfileStore's own API-access probe uses its dedicated `____PS` key.
