# ⚡ Complete WebSocket Architecture & Protocol Lab

A full-stack, cross-platform demonstration of **real-time bi-directional communication** using WebSockets (RFC 6455). This repository includes a native **iOS Application** built with SwiftUI & `URLSessionWebSocketTask`, an interactive **Node.js WebSocket Server**, and a modern **Web Client Visualizer & Inspector**.

---

## 📁 Repository Structure

```
Websocket_github/
├── ios-app/                   # Native iOS Swift Application
│   ├── Websocket/             # SwiftUI Source Files
│   │   ├── WebSocketManager.swift  # Core URLSessionWebSocketTask Engine
│   │   ├── ConnectView.swift        # Lifecycle & Live Frame Inspector
│   │   ├── ChatView.swift           # Bi-directional Chat UI
│   │   ├── PingView.swift           # RTT Latency & Heartbeat Visualizer
│   │   ├── Models.swift             # Data Schemas & Enums
│   │   └── ContentView.swift        # Tab Navigation Container
│   └── Websocket.xcodeproj    # Xcode Project Workspace
├── server/                    # Node.js Backend & Web Visualizer
│   ├── server.js              # HTTP + WebSocket Server (ws library)
│   ├── index.html            # Web Inspector Dashboard
│   └── package.json           # Node.js Dependencies
└── README.md                  # Comprehensive Documentation
```

---

## 🏗 System Architecture & Flow

```
+------------------------------------+          +------------------------------------+
|            iOS Client              |          |         Browser Web Client         |
|   (URLSessionWebSocketTask / Swift)|          |    (WebSocket API / Vanilla JS)    |
+-----------------+------------------+          +-----------------+------------------+
                  |                                               |
                  |  HTTP Upgrade (101 Switching Protocols)       |  HTTP Upgrade (101)
                  +-----------------------+-----------------------+
                                          |
                                          v
                        +-----------------------------------+
                        |         Node.js Server            |
                        |      (http + ws library)          |
                        |      - Broadcast Engine           |
                        |      - Client Registry            |
                        |      - Heartbeat / Ping Responder |
                        +-----------------------------------+
```

---

## 🧠 Core WebSocket Concepts Demonstrated

### 1. The Upgrade Handshake
WebSockets begin as a standard HTTP/1.1 request containing upgrade headers:
- `Upgrade: websocket`
- `Connection: Upgrade`
- `Sec-WebSocket-Key: <base64-key>`

The server validates the key and responds with `101 Switching Protocols`. From this point forward, TCP frames switch from HTTP request-response to persistent, bi-directional WebSocket frames.

### 2. Full-Duplex Framing
Unlike HTTP (where the client must request and wait), WebSockets allow both client and server to push text or binary data independently at any time.

### 3. The "Re-arm" Receive Loop Pattern
In Apple's `URLSessionWebSocketTask`, message reception is not an asynchronous stream. You must recursively call `.receive()` after every message to keep listening for subsequent incoming frames.

```swift
private func scheduleReceive() {
    task?.receive { [weak self] result in
        switch result {
        case .success(let message):
            self?.handleIncoming(message)
            self?.scheduleReceive() // 🔄 Re-arm receive handler
        case .failure(let error):
            self?.handleDisconnect(error)
        }
    }
}
```

### 4. Control Frames (Ping / Pong Heartbeat)
Ping (`0x9`) and Pong (`0xA`) are built-in control frames used to:
- Keep connections active through aggressive NAT and firewall timeouts.
- Measure Round-Trip Time (RTT) latency.
- Detect silently dropped TCP connections before sending data frames.

### 5. Graceful Teardown & Close Codes
Connections are closed via standard Close control frames (`0x8`) carrying a status code:
- **`1000`**: Normal Closure (Clean disconnect)
- **`1001`**: Going Away (Browser tab/app closing)
- **`1006`**: Abnormal Closure (Connection dropped without close frame)

---

## 🚀 Quick Start Guide

### Prerequisites
- **iOS App**: Xcode 15+ & iOS 17+ Simulator / Device
- **Server**: Node.js v18+ & npm

---

### 1. Running the Node.js Server & Web Dashboard

```bash
# Navigate to the server folder
cd server

# Install dependencies
npm install

# Run the server
npm start
```

The server will start at: **`http://localhost:3000`**

Open `http://localhost:3000` in **two separate browser tabs** to experience real-time messaging, user list updates, typing indicators, and frame inspection.

---

### 2. Running the iOS Native App

1. Open `ios-app/Websocket.xcodeproj` in Xcode.
2. Select your target simulator (e.g., iPhone 16 Pro).
3. Press `Cmd + R` to build and run.
4. In the **Connect** tab:
   - Tap **Local Node.js** (`ws://localhost:3000`) or a public server like `wss://echo.websocket.events`.
   - Tap **Connect** to perform the handshake.
   - Switch between **Chat**, **Ping/Pong**, and **Connect** tabs.

---

## 📡 WebSocket Message Protocol Specification

The Node.js server and clients communicate using a structured JSON protocol:

| Message Type | Direction | Payload Example | Description |
| :--- | :--- | :--- | :--- |
| **`welcome`** | Server → Client | `{"type":"welcome", "clientId":1, "username":"User_1", "users":[...]}` | Initial connection response |
| **`chat`** | Bi-directional | `{"type":"chat", "text":"Hello world!"}` | Public channel broadcast |
| **`dm`** | Bi-directional | `{"type":"dm", "to":"User_2", "text":"Secret msg"}` | Direct private message |
| **`rename`** | Client → Server | `{"type":"rename", "username":"Alice"}` | Change display name |
| **`typing`** | Bi-directional | `{"type":"typing", "isTyping":true}` | Real-time typing status |
| **`ping`** / **`pong`** | Bi-directional | `{"type":"ping", "clientTime":1700000000}` | Latency RTT measurement |
| **`user_joined`** | Server → All | `{"type":"user_joined", "username":"User_2"}` | Broadcast when user connects |
| **`user_left`** | Server → All | `{"type":"user_left", "username":"User_2"}` | Broadcast on disconnect |

---

## 🛠 Features Overview

### iOS Native App (`SwiftUI` + `URLSessionWebSocketTask`)
- 🟢 **Live Connection State Machine**: Visual indicators for `.disconnected`, `.connecting`, `.connected`, `.disconnecting`, `.error`.
- 💬 **Interactive Chat**: Built-in echo & JSON protocol support with auto-scroll and haptic feedback.
- ⏱ **Heartbeat Inspector**: Manual & automated Ping/Pong generator with a mini RTT latency chart (Min / Max / Avg RTT).
- 📜 **Event Log Stream**: Real-time log capturing every frame sent, frame received, ping, pong, and handshake event.

### Web Inspector & Visualizer (`HTML5` + `Vanilla JS`)
- 🎨 **Modern Dark-Mode Dashboard**: Glassmorphic UI styled with Inter typography.
- 🔍 **Frame Inspector**: Real-time packet log with microsecond timestamp tracking.
- 👥 **Live Active User Roster**: Real-time join/leave/rename updates across tabs and iOS devices.

---

## 📄 License
This project is licensed under the MIT License - feel free to use it for learning, teaching, or production reference!
