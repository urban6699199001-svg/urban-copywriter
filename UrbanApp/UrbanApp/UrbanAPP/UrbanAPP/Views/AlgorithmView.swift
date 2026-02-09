//
//  AlgorithmView.swift
//  UrbanAPP
//

import SwiftUI

struct AlgorithmView: View {
    @State private var captionInput = ""
    @State private var analysisResult: AlgorithmAnalysisResponse?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("貼上你的文案，AI 會從 4 個維度分析演算法友善度")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("互動誘發力 / 停留時間 / 分享潛力 / Hashtag 觸及")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    TextEditor(text: $captionInput)
                        .frame(minHeight: 150)
                        .focused($isFocused)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            if captionInput.isEmpty {
                                Text("在這裡貼上你的文案...")
                                    .foregroundStyle(.tertiary)
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(captionInput.count) 字")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        isFocused = false
                        Task { await analyze() }
                    } label: {
                        ActionButtonLabel(text: "分析演算法分數", icon: "chart.bar.fill", isLoading: isLoading)
                    }
                    .disabled(captionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)

                    if let result = analysisResult {
                        if let score = result.score, score > 0 {
                            VStack(spacing: 8) {
                                ScoreRingView(score: score)
                                Text("演算法友善度")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        VStack(spacing: 4) {
                            HStack {
                                Text("分析報告")
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Text("每個區塊可獨立複製")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandGold)
                            }
                        }

                        ForEach(result.sections) { section in
                            AlgorithmSectionCard(
                                emoji: section.emoji,
                                label: section.label,
                                score: section.score,
                                content: section.content
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
            .navigationTitle("演算法分析")
            .alert("錯誤", isPresented: $showError) {
                Button("確定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func analyze() async {
        isLoading = true
        defer { isLoading = false }

        do {
            analysisResult = try await APIService.shared.analyzeAlgorithm(caption: captionInput)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
