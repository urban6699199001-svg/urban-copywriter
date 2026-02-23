//
//  PaywallView.swift
//  UrbanAPP
//
//  訂閱付費牆 — 引導用戶購買 Pro 訂閱
//  包含 Apple 審核要求的：訂閱資訊、隱私政策、使用條款連結
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?
    @State private var isLoadingProducts = true

    // Apple 審核要求的連結
    private let privacyURL = URL(string: "https://urban6699199001-svg.github.io/urban-copywriter/privacy.html")!
    private let termsURL = URL(string: "https://urban6699199001-svg.github.io/urban-copywriter/terms.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 頂部品牌區
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.brandGold)

                        Text("URBAN Pro")
                            .font(.largeTitle.weight(.bold))

                        Text("解鎖無限 AI 文案生成")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // MARK: - 功能列表
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", text: "無限次 AI 文案生成", highlight: true)
                        FeatureRow(icon: "photo.fill", text: "無限次 AI 圖片生成")
                        FeatureRow(icon: "person.crop.rectangle", text: "無限次背景替換")
                        FeatureRow(icon: "wand.and.stars", text: "AI 時尚排版設計")
                        FeatureRow(icon: "chart.bar.fill", text: "演算法分析 & 優化")
                        FeatureRow(icon: "flame.fill", text: "即時熱門趨勢文案")
                    }
                    .padding(.horizontal)

                    // MARK: - 訂閱方案
                    if isLoadingProducts && subscriptionManager.products.isEmpty {
                        ProgressView("載入方案中...")
                            .padding()
                    } else if !subscriptionManager.products.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.products, id: \.id) { product in
                                SubscriptionOptionCard(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id,
                                    onSelect: { selectedProduct = product }
                                )
                            }
                        }
                        .padding(.horizontal)

                        // 購買按鈕
                        if let product = selectedProduct {
                            Button {
                                Task { await subscriptionManager.purchase(product) }
                            } label: {
                                HStack {
                                    if subscriptionManager.isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("訂閱 \(product.displayName)")
                                    }
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.brandNavy, Color.brandNavy.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(subscriptionManager.isPurchasing)
                            .padding(.horizontal)
                        }
                    } else {
                        // 產品載入失敗 — 不顯示錯誤，顯示友善提示
                        VStack(spacing: 8) {
                            Text("訂閱方案準備中")
                                .font(.subheadline.weight(.medium))
                            Text("請稍後再試，或前往 App Store 訂閱")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("重新載入") {
                                Task {
                                    isLoadingProducts = true
                                    await subscriptionManager.loadProducts()
                                    selectedProduct = subscriptionManager.products.last
                                    isLoadingProducts = false
                                }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                        .padding()
                    }

                    // MARK: - 錯誤訊息
                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // MARK: - 訂閱說明（Apple 審核要求 - Guideline 3.1.2）
                    VStack(spacing: 6) {
                        Text("URBAN Pro 自動續訂訂閱")
                            .font(.caption.weight(.semibold))

                        Text("月訂閱：每月自動續訂 | 年訂閱：每年自動續訂\n付款將透過您的 Apple ID 帳戶收取。\n訂閱會在到期前 24 小時內自動續訂並收費。\n您可以隨時在「設定 > Apple ID > 訂閱項目」管理或取消訂閱。\n取消訂閱後，您仍可使用服務至當期結束。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)

                    // MARK: - 恢復購買 & 條款連結（Apple 審核要求）
                    VStack(spacing: 10) {
                        Button("恢復購買") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // Apple 審核要求：必須有隱私政策和使用條款的可點擊連結
                        HStack(spacing: 16) {
                            Link("使用條款 (EULA)", destination: termsURL)
                                .font(.caption2)
                                .foregroundStyle(.blue)

                            Text("|")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)

                            Link("隱私政策", destination: privacyURL)
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                isLoadingProducts = true
                await subscriptionManager.loadProducts()
                selectedProduct = subscriptionManager.products.last

                // 自動重試最多 3 次（每次間隔 2 秒）
                var attempts = 0
                while subscriptionManager.products.isEmpty && attempts < 3 {
                    try? await Task.sleep(for: .seconds(2))
                    attempts += 1
                    await subscriptionManager.loadProducts()
                    selectedProduct = subscriptionManager.products.last
                }
                isLoadingProducts = false
            }
            .onChange(of: subscriptionManager.isSubscribed) { _, subscribed in
                if subscribed { dismiss() }
            }
        }
    }
}

// MARK: - 功能列表行

struct FeatureRow: View {
    let icon: String
    let text: String
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(highlight ? Color.brandGold : .secondary)
                .frame(width: 28)

            Text(text)
                .font(highlight ? .body.weight(.semibold) : .body)

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        }
    }
}

// MARK: - 訂閱方案卡片

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    private var isYearly: Bool {
        product.id.contains("yearly")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName)
                            .font(.headline)

                        if isYearly {
                            Text("最划算")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandGold)
                                .clipShape(Capsule())
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isSelected ? Color.brandGold : .primary)

                    Text(isYearly ? "/年" : "/月")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.brandGold : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
