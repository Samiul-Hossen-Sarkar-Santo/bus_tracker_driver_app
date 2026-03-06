# Sharing Backend (Cloud Functions)

This backend accepts anonymous app calls and writes to RTDB using Admin SDK.
It enforces:

- one active session per bus
- server-side 3 hour expiry
- location updates only for the active session token
- scheduled cleanup every 5 minutes for expired sessions

## Deploy

1. Install dependencies:
   - `cd functions`
   - `npm install`
2. Deploy:
   - `firebase deploy --only functions`

## Endpoints

Assuming your function base URL is:
`https://asia-southeast1-<project-id>.cloudfunctions.net`

- `POST /startSharing`
- `POST /updateLocation`
- `POST /stopSharing`

## Realtime Database paths used by backend

- `Buses/<busId>/status`
- `Buses/<busId>/location`
- `ActiveShareSessions/<busId>`
- `ServerMetrics/sharing/*`
