const crypto = require("crypto");
const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");

admin.initializeApp();
const db = admin.database();

const REGION = "asia-southeast1";
const SESSION_TTL_MS = 3 * 60 * 60 * 1000;

function sendJson(res, statusCode, body) {
  res.status(statusCode).set("Content-Type", "application/json").send(body);
}

function rejectWrongMethod(req, res) {
  if (req.method !== "POST") {
    sendJson(res, 405, {ok: false, error: "Method Not Allowed"});
    return true;
  }
  return false;
}

function isValidBusId(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{2,80}$/.test(value);
}

function parseLocation(location) {
  if (!location || typeof location !== "object") return null;
  const lat = Number(location.lat);
  const long = Number(location.long);
  if (!Number.isFinite(lat) || !Number.isFinite(long)) return null;
  if (lat < -90 || lat > 90 || long < -180 || long > 180) return null;
  return {lat, long};
}

async function incrementCounter(path, amount = 1) {
  const ref = db.ref(path);
  await ref.transaction((current) => {
    const base = typeof current === "number" ? current : 0;
    return base + amount;
  });
}

async function syncActiveSessionCount(nowMs = Date.now()) {
  const sessionsSnap = await db.ref("ActiveShareSessions").get();
  let activeSessions = 0;

  if (sessionsSnap.exists()) {
    sessionsSnap.forEach((child) => {
      const session = child.val();
      if (
        session &&
        session.active === true &&
        typeof session.expiresAtMs === "number" &&
        session.expiresAtMs > nowMs
      ) {
        activeSessions += 1;
      }
    });
  }

  await db.ref("ServerMetrics/sharing").update({
    activeSessions,
    lastSyncedAt: admin.database.ServerValue.TIMESTAMP,
  });
}

function createSessionPayload({busId, body, nowMs, expiresAtMs, sessionId}) {
  return {
    busId,
    sessionId,
    active: true,
    startedAtMs: nowMs,
    expiresAtMs,
    routeId: body.routeId ?? null,
    routeName: body.routeName ?? null,
    busNumber: body.busNumber ?? null,
    driverName: body.driverName ?? null,
  };
}

exports.startSharing = onRequest(
    {region: REGION, cors: true, invoker: "public"},
    async (req, res) => {
  if (rejectWrongMethod(req, res)) return;

  const body = req.body || {};
  const busId = body.busId;
  const location = parseLocation(body.location);

  if (!isValidBusId(busId)) {
    sendJson(res, 400, {ok: false, error: "Invalid busId."});
    return;
  }
  if (!location) {
    sendJson(res, 400, {ok: false, error: "Invalid location payload."});
    return;
  }

  const nowMs = Date.now();
  const expiresAtMs = nowMs + SESSION_TTL_MS;
  const sessionId = crypto.randomUUID();
  const sessionRef = db.ref(`ActiveShareSessions/${busId}`);

  try {
    const tx = await sessionRef.transaction((current) => {
      if (
        current &&
        current.active === true &&
        typeof current.expiresAtMs === "number" &&
        current.expiresAtMs > nowMs
      ) {
        return;
      }
      return createSessionPayload({
        busId,
        body,
        nowMs,
        expiresAtMs,
        sessionId,
      });
    });

    if (!tx.committed) {
      sendJson(res, 409, {ok: false, error: "This bus is already in use."});
      return;
    }

    await db.ref(`Buses/${busId}`).update({
      status: true,
      location: {
        lat: location.lat,
        long: location.long,
      },
    });

    await Promise.all([
      incrementCounter("ServerMetrics/sharing/totalSessions", 1),
      syncActiveSessionCount(nowMs),
    ]);

    sendJson(res, 200, {
      ok: true,
      sessionId,
      expiresAtMs,
    });
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      error: `startSharing failed: ${error.message}`,
    });
  }
    },
);

exports.updateLocation = onRequest(
    {region: REGION, cors: true, invoker: "public"},
    async (req, res) => {
  if (rejectWrongMethod(req, res)) return;

  const body = req.body || {};
  const busId = body.busId;
  const sessionId = body.sessionId;
  const location = parseLocation(body.location);

  if (!isValidBusId(busId)) {
    sendJson(res, 400, {ok: false, error: "Invalid busId."});
    return;
  }
  if (typeof sessionId !== "string" || sessionId.length < 12) {
    sendJson(res, 400, {ok: false, error: "Invalid sessionId."});
    return;
  }
  if (!location) {
    sendJson(res, 400, {ok: false, error: "Invalid location payload."});
    return;
  }

  const nowMs = Date.now();
  const sessionRef = db.ref(`ActiveShareSessions/${busId}`);

  try {
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists()) {
      sendJson(res, 409, {ok: false, error: "No active session for this bus."});
      return;
    }

    const session = sessionSnap.val();
    if (session.sessionId !== sessionId) {
      sendJson(res, 403, {ok: false, error: "Session mismatch."});
      return;
    }
    if (session.active !== true) {
      sendJson(res, 409, {ok: false, error: "Session is not active."});
      return;
    }

    if (typeof session.expiresAtMs === "number" && session.expiresAtMs <= nowMs) {
      const rootUpdates = {};
      rootUpdates[`ActiveShareSessions/${busId}/active`] = false;
      rootUpdates[`ActiveShareSessions/${busId}/endedAtMs`] = nowMs;
      rootUpdates[`ActiveShareSessions/${busId}/endedReason`] = "expired_update";
      rootUpdates[`ActiveShareSessions/${busId}/serverEndedAt`] =
        admin.database.ServerValue.TIMESTAMP;
      rootUpdates[`Buses/${busId}/status`] = false;
      await db.ref().update(rootUpdates);
      await syncActiveSessionCount(nowMs);
      sendJson(res, 409, {ok: false, error: "Session expired."});
      return;
    }

    await db.ref().update({
      [`Buses/${busId}/location/lat`]: location.lat,
      [`Buses/${busId}/location/long`]: location.long,
      [`ActiveShareSessions/${busId}/lastLocationAtMs`]: nowMs,
    });

    await incrementCounter("ServerMetrics/sharing/totalLocationUpdates", 1);
    sendJson(res, 200, {ok: true, expiresAtMs: session.expiresAtMs});
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      error: `updateLocation failed: ${error.message}`,
    });
  }
    },
);

exports.stopSharing = onRequest(
    {region: REGION, cors: true, invoker: "public"},
    async (req, res) => {
  if (rejectWrongMethod(req, res)) return;

  const body = req.body || {};
  const busId = body.busId;
  const sessionId = body.sessionId;
  const reason = typeof body.reason === "string" && body.reason.trim()
    ? body.reason.trim()
    : "manual_stop";

  if (!isValidBusId(busId)) {
    sendJson(res, 400, {ok: false, error: "Invalid busId."});
    return;
  }
  if (typeof sessionId !== "string" || sessionId.length < 12) {
    sendJson(res, 400, {ok: false, error: "Invalid sessionId."});
    return;
  }

  const nowMs = Date.now();
  const sessionRef = db.ref(`ActiveShareSessions/${busId}`);

  try {
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists()) {
      await db.ref(`Buses/${busId}/status`).set(false);
      await syncActiveSessionCount(nowMs);
      sendJson(res, 200, {ok: true, released: true});
      return;
    }

    const session = sessionSnap.val();
    if (session.sessionId !== sessionId) {
      sendJson(res, 403, {ok: false, error: "Session mismatch."});
      return;
    }

    const rootUpdates = {
      [`ActiveShareSessions/${busId}/active`]: false,
      [`ActiveShareSessions/${busId}/endedAtMs`]: nowMs,
      [`ActiveShareSessions/${busId}/endedReason`]: reason,
      [`ActiveShareSessions/${busId}/serverEndedAt`]:
        admin.database.ServerValue.TIMESTAMP,
      [`Buses/${busId}/status`]: false,
    };

    await db.ref().update(rootUpdates);
    await syncActiveSessionCount(nowMs);

    sendJson(res, 200, {ok: true, released: true});
  } catch (error) {
    sendJson(res, 500, {
      ok: false,
      error: `stopSharing failed: ${error.message}`,
    });
  }
    },
);

exports.cleanupExpiredSharingSessions = onSchedule(
    {
      region: REGION,
      schedule: "every 5 minutes",
      timeZone: "Asia/Dhaka",
    },
    async () => {
      const nowMs = Date.now();
      const sessionsSnap = await db.ref("ActiveShareSessions").get();

      if (!sessionsSnap.exists()) {
        await syncActiveSessionCount(nowMs);
        return;
      }

      const rootUpdates = {};
      let expiredCount = 0;

      sessionsSnap.forEach((child) => {
        const busId = child.key;
        const session = child.val();
        if (
          !busId ||
          !session ||
          session.active !== true ||
          typeof session.expiresAtMs !== "number" ||
          session.expiresAtMs > nowMs
        ) {
          return;
        }

        rootUpdates[`ActiveShareSessions/${busId}/active`] = false;
        rootUpdates[`ActiveShareSessions/${busId}/endedAtMs`] = nowMs;
        rootUpdates[`ActiveShareSessions/${busId}/endedReason`] = "expired_cleanup";
        rootUpdates[`ActiveShareSessions/${busId}/serverEndedAt`] =
          admin.database.ServerValue.TIMESTAMP;
        rootUpdates[`Buses/${busId}/status`] = false;
        expiredCount += 1;
      });

      if (expiredCount > 0) {
        await db.ref().update(rootUpdates);
        await incrementCounter("ServerMetrics/sharing/expiredStops", expiredCount);
      }

      await syncActiveSessionCount(nowMs);
    },
);
