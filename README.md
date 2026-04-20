# Offline-First Digital Wallet

An offline-first digital wallet with a Flutter mobile app and a Node.js + TypeScript backend.

## Architecture

- `backend/`: Express + TypeScript API with PostgreSQL as the source of truth.
- `mobile/`: Flutter app with Riverpod, `sqflite`, and cryptographic helpers for offline payments.

## Product Model

Each user has:

- `online_balance`: authoritative server-controlled balance
- `offline_balance`: server-assigned balance that can be spent locally when offline

Offline payments are created and signed on-device, stored locally with `PENDING_SYNC`, and later verified by the backend sync engine.

## Current Scope

This scaffold targets Phase 1:

- backend project structure
- mobile Flutter structure
- wallet and transaction domain models
- local database entry points
- key management interfaces

## Suggested Next Steps

1. Implement backend registration and login with JWT.
2. Create PostgreSQL schema and migrations.
3. Wire Flutter auth, local storage, and first-launch key generation.
4. Add real API integration between mobile and backend.
