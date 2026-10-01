/**
 * WebSocket Demo Server
 *
 * This server demonstrates the core WebSocket concepts:
 *  - Connection lifecycle  (open → message → close)
 *  - Broadcasting to all connected clients
 *  - Ping / pong heartbeat
 *  - Named "rooms" via a simple message protocol
 *  - Graceful disconnection handling
 */

const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer, WebSocket } = require("ws");

// ─────────────────────────── HTTP server (serves the HTML client) ──────────────
const PORT = 3000;

const MIME = {
  ".html": "text/html",
  ".css": "text/css",
  ".js": "text/javascript",
};

const httpServer = http.createServer((req, res) => {
  const filePath = path.join(__dirname, req.url === "/" ? "index.html" : req.url);
  const ext = path.extname(filePath);
  const contentType = MIME[ext] || "text/plain";

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    res.writeHead(200, { "Content-Type": contentType });
    res.end(data);
  });
});

// ─────────────────────────── WebSocket server ─────────────────────────────────
const wss = new WebSocketServer({ server: httpServer });

// Track every connected client with metadata
let clientIdCounter = 1;
const clients = new Map(); // clientId → { ws, username, connectedAt }

// ── Helpers ───────────────────────────────────────────────────────────────────

function broadcast(senderID, payload) {
  const message = JSON.stringify(payload);
  for (const [id, client] of clients) {
    if (client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(message);
    }
  }
}

function sendTo(clientId, payload) {
  const client = clients.get(clientId);
  if (client && client.ws.readyState === WebSocket.OPEN) {
    client.ws.send(JSON.stringify(payload));
  }
}

function getConnectedUsers() {
  return [...clients.values()].map((c) => ({
    id: c.id,
    username: c.username,
    connectedAt: c.connectedAt,
  }));
}

// ── Connection handler ────────────────────────────────────────────────────────

wss.on("connection", (ws, req) => {
  const clientId = clientIdCounter++;
  const connectedAt = new Date().toISOString();
  const defaultUsername = `User_${clientId}`;

  clients.set(clientId, { id: clientId, ws, username: defaultUsername, connectedAt });

  console.log(`[+] Client ${clientId} connected  (total: ${clients.size})`);

  // 1️⃣  Tell the new client its own ID and the current user list
  sendTo(clientId, {
    type: "welcome",
    clientId,
    username: defaultUsername,
    users: getConnectedUsers(),
    serverTime: new Date().toISOString(),
  });

  // 2️⃣  Tell everyone else a new user joined
  broadcast(clientId, {
    type: "user_joined",
    clientId,
    username: defaultUsername,
    users: getConnectedUsers(),
    timestamp: new Date().toISOString(),
  });

  // ── Message handler ──────────────────────────────────────────────────────────
  ws.on("message", (raw) => {
    const rawStr = raw.toString();
    let msg;

    try {
      msg = JSON.parse(rawStr);
    } catch {
      // Handle plain-text frames (e.g. basic echo tests)
      console.log(`[text] from=${clients.get(clientId)?.username}: ${rawStr}`);
      broadcast(clientId, {
        type: "chat",
        clientId,
        username: clients.get(clientId)?.username || `User_${clientId}`,
        text: rawStr,
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const client = clients.get(clientId);
    console.log(`[msg] type=${msg.type} from=${client?.username}`);

    switch (msg.type) {
      // ── Chat message ────────────────────────────────────────────────────────
      case "chat": {
        broadcast(clientId, {
          type: "chat",
          clientId,
          username: client.username,
          text: msg.text,
          timestamp: new Date().toISOString(),
        });
        break;
      }

      // ── Private (direct) message ─────────────────────────────────────────────
      case "dm": {
        const target = [...clients.values()].find((c) => c.username === msg.to);
        if (!target) {
          sendTo(clientId, { type: "error", text: `User "${msg.to}" not found` });
          break;
        }
        const dm = {
          type: "dm",
          from: client.username,
          to: target.username,
          text: msg.text,
          timestamp: new Date().toISOString(),
        };
        sendTo(target.id, dm);
        sendTo(clientId, dm); // echo to sender too
        break;
      }

      // ── Rename ───────────────────────────────────────────────────────────────
      case "rename": {
        const oldName = client.username;
        const newName = (msg.username || "").trim().slice(0, 24);
        if (!newName) break;
        client.username = newName;
        broadcast(clientId, {
          type: "rename",
          clientId,
          oldName,
          newName,
          users: getConnectedUsers(),
          timestamp: new Date().toISOString(),
        });
        break;
      }

      // ── Ping (latency measurement) ───────────────────────────────────────────
      case "ping": {
        sendTo(clientId, { type: "pong", clientTime: msg.clientTime, serverTime: Date.now() });
        break;
      }

      // ── Typing indicator ─────────────────────────────────────────────────────
      case "typing": {
        for (const [id] of clients) {
          if (id !== clientId) {
            sendTo(id, { type: "typing", username: client.username, isTyping: msg.isTyping });
          }
        }
        break;
      }

      default:
        sendTo(clientId, { type: "error", text: `Unknown message type: ${msg.type}` });
    }
  });

  // ── Close handler ────────────────────────────────────────────────────────────
  ws.on("close", (code, reason) => {
    const client = clients.get(clientId);
    console.log(`[-] Client ${clientId} (${client?.username}) disconnected  code=${code}`);
    clients.delete(clientId);

    broadcast(null, {
      type: "user_left",
      clientId,
      username: client?.username,
      users: getConnectedUsers(),
      timestamp: new Date().toISOString(),
    });
  });

  // ── Error handler ────────────────────────────────────────────────────────────
  ws.on("error", (err) => {
    console.error(`[err] Client ${clientId}:`, err.message);
  });
});

// ─────────────────────────── Start ────────────────────────────────────────────
httpServer.listen(PORT, () => {
  console.log(`\n🚀 WebSocket Demo Server running at http://localhost:${PORT}\n`);
  console.log("Open the URL in TWO browser tabs to see real-time messaging!\n");
});
