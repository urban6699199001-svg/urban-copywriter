//
//  ContentView.swift
//  UrbanAPP
//
//  Created by 123 on 2026/2/9.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

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
    }
}

#Preview {
    ContentView()
}
