//
//  TrendingView.swift
//  UrbanAPP
//

import SwiftUI

struct TrendingView: View {
    @State private var topic = ""
    @State private var captionOptions: [CaptionOption] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isFocused: Bool

    private let suggestions = [
        "下班後的自律生活",
        "為什麼要學理財",
        "30歲前該懂的事",
        "被動收入的真相",
        "好習慣vs壞習慣",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("輸入主題")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        TextField("例如：下班後的自律生活", text: $topic)
                            .textFieldStyle(.roundedBorder)
                            .focused($isFocused)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    topic = suggestion
                                    isFocused = false
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                    }

                    Button {
                        isFocused = false
                        Task { await generateTrending() }
                    } label: {
                        ActionButtonLabel(text: "生成爆款文案", icon: "flame.fill", isLoading: isLoading)
                    }
                    .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)

                    if !captionOptions.isEmpty {
                        VStack(spacing: 4) {
                            HStack {
                                Text("熱門風格文案")
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text("\(captionOptions.count) 個風格")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("每個風格都可以獨立複製，直接貼上使用")
                                .font(.caption)
                                .foregroundStyle(Color.brandGold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(captionOptions) { option in
                            CaptionOptionCard(
                                emoji: option.emoji,
                                label: option.label,
                                description: option.description,
                                content: option.content
                            )
                        }
                    }
                }
                .padding()
            }
            .onTapGesture { isFocused = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isFocused = false }
                }
            }
            .navigationTitle("熱門文案")
            .alert("錯誤", isPresented: $showError) {
                Button("確定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func generateTrending() async {
        isLoading = true
        defer { isLoading = false }

        do {
            captionOptions = try await APIService.shared.trendingCaption(topic: topic)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
