//
//  ContentView.swift
//  UrbanAPP
//
//  Created by 123 on 2026/2/9.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showPaywall = false
    var subscriptionManager = SubscriptionManager.shared

    @State private var devTapCount = 0
    @State private var showDevAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ImageToCaptionView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("圖片文案")
                }
                .tag(0)

            TextToImageView()
                .tabItem {
                    Image(systemName: "paintbrush.fill")
                    Text("AI 生圖")
                }
                .tag(1)

            DesignView()
                .tabItem {
                    Image(systemName: "textformat.abc")
                    Text("排版設計")
                }
                .tag(2)

            TrendingView()
                .tabItem {
                    Image(systemName: "flame.fill")
                    Text("熱門文案")
                }
                .tag(3)

            AlgorithmView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("演算法")
                }
                .tag(4)
        }
        .tint(.indigo)
        .overlay(alignment: .top) {
            // 開發者無限模式不顯示 banner
            if !subscriptionManager.isSubscribed && !subscriptionManager.isDevMode {
                FreeUsageBanner(
                    remaining: subscriptionManager.freeUsesRemaining,
                    onUpgrade: { showPaywall = true },
                    onSecretTap: {
                        devTapCount += 1
                        if devTapCount >= 5 {
                            subscriptionManager.enableDevMode()
                            showDevAlert = true
                            devTapCount = 0
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            devTapCount = 0
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("🔓 開發者模式已啟用", isPresented: $showDevAlert) {
            Button("好的") {}
        } message: {
            Text("你的手機已設為無限使用！")
        }
    }
}

// MARK: - 免費用戶使用次數提示

struct FreeUsageBanner: View {
    let remaining: Int
    let onUpgrade: () -> Void
    var onSecretTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: remaining > 0 ? "sparkle" : "lock.fill")
                .font(.caption)
                .foregroundStyle(remaining > 0 ? Color.brandGold : .red)

            Text(remaining > 0 ? "今日免費次數：\(remaining)/3" : "今日免費次數已用完")
                .font(.caption.weight(.medium))
                .onTapGesture { onSecretTap?() }

            Spacer()

            Button(action: onUpgrade) {
                Text("升級 Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.brandGold)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
}
