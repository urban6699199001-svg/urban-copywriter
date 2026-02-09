//
//  SharedComponents.swift
//  UrbanAPP
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let brandNavy = Color(red: 0.1, green: 0.12, blue: 0.25)
    static let brandGold = Color(red: 0.85, green: 0.7, blue: 0.35)
    static let brandDark = Color(red: 0.06, green: 0.07, blue: 0.15)
}

// MARK: - Upload Placeholder

struct UploadPlaceholder: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(.quaternary)
        )
    }
}

// MARK: - Action Button

struct ActionButtonLabel: View {
    let text: String
    let icon: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: icon)
            }
            Text(isLoading ? "處理中..." : text)
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: isLoading ? [.gray] : [Color.brandNavy, Color.brandNavy.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 獨立文案選項卡片（每個都能獨立複製）

struct CaptionOptionCard: View {
    let emoji: String
    let label: String
    let description: String
    let content: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題列
            HStack(alignment: .top) {
                Text(emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 複製按鈕
                Button {
                    UIPasteboard.general.string = content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(copied ? "已複製" : "複製")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(copied ? .green : Color.brandGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(copied ? Color.green.opacity(0.1) : Color.brandGold.opacity(0.1))
                    )
                }
            }

            // 分隔線
            Rectangle()
                .fill(Color.brandGold.opacity(0.2))
                .frame(height: 1)

            // 文案內容
            Text(content)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            // 底部操作列
            HStack(spacing: 12) {
                Spacer()

                ShareLink(item: content) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.brandGold.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - 演算法分析區塊卡片（每個區塊獨立複製）

struct AlgorithmSectionCard: View {
    let emoji: String
    let label: String
    let score: String?
    let content: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(emoji)
                    .font(.title3)
                Text(label)
                    .font(.subheadline.weight(.bold))

                if let score = score {
                    Spacer()
                    Text(score)
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Color.brandGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandGold.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
            }

            Text(content)
                .font(.callout)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 演算法總分圓環

struct ScoreRingView: View {
    let score: Int

    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return Color.brandGold }
        if score >= 40 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 10)

            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8), value: score)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)
                Text("/ 100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - 舊版 ResultCard（保留給排版設計用）

struct ResultCard: View {
    let title: String
    let content: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()

                Button {
                    UIPasteboard.general.string = content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "已複製" : "複製", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                ShareLink(item: content) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            Text(content)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
