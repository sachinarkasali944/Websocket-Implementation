//
//  ContentView.swift
//  Websocket
//
//  Created by Sachin Arkasali on 08/05/26.
//
//  Root of the app. Owns the single WebSocketManager instance and
//  injects it into the environment so all child views share the same connection.

import SwiftUI

struct ContentView: View {
    @StateObject private var ws = WebSocketManager()

    var body: some View {
        TabView {
            ConnectView()
                .tabItem {
                    Label("Connect", systemImage: ws.connectionState.isConnected
                          ? "bolt.fill" : "bolt.slash")
                }
                .badge(ws.connectionState.isConnected ? "" : "!")

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(ws.messages.count)

            PingView()
                .tabItem {
                    Label("Ping", systemImage: "dot.radiowaves.left.and.right")
                }
        }
        .environmentObject(ws)
    }
}

#Preview {
    ContentView()
}
