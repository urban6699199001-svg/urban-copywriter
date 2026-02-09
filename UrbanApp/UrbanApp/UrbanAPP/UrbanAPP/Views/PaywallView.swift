//
//  PaywallView.swift
//  UrbanAPP
//
//  訂閱付費牆 — 引導用戶購買 Pro 訂閱
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    var subscriptionManager = SubscriptionManager.shared
    @State private var selectedProduct: Product?

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
                    if subscriptionManager.products.isEmpty {
                        VStack(spacing: 12) {
                            if let error = subscriptionManager.loadError {
                                // 有錯誤，顯示原因
                                VStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    Button("重新載入") {
                                        Task { await subscriptionManager.loadProducts() }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                // 還在載入中
                                ProgressView("載入方案中...")
                            }
                        }
                        .padding()
                    } else {
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
                    }

                    // MARK: - 購買按鈕
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

                    // MARK: - 錯誤訊息
                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // MARK: - 恢復購買 & 條款
                    VStack(spacing: 8) {
                        Button("恢復購買") {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Text("訂閱會自動續訂，可隨時在「設定 > Apple ID > 訂閱項目」取消")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
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
                await subscriptionManager.loadProducts()
                // 預設選中年訂閱（通常更划算）
                selectedProduct = subscriptionManager.products.last
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
