//
//  SubscriptionManager.swift
//  UrbanAPP
//
//  StoreKit 2 訂閱管理器
//  處理訂閱購買、驗證、狀態監聽
//

import Foundation
import StoreKit

/// 訂閱產品 ID（需要在 App Store Connect 設定一樣的 ID）
enum SubscriptionProduct: String, CaseIterable {
    case monthly = "com.urban.copywriter.monthly"    // 月訂閱
    case yearly  = "com.urban.copywriter.yearly"     // 年訂閱
}

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // 訂閱狀態
    var isSubscribed = false

    // 免費試用次數（未訂閱用戶每天可用 3 次）
    var freeUsesRemaining: Int = 3
    private let maxFreeUses = 3

    // StoreKit 產品
    var products: [Product] = []
    var purchaseError: String?
    var isPurchasing = false
    var loadError: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        // 啟動交易監聽
        updateListenerTask = listenForTransactions()

        // 載入今日免費次數
        loadFreeUses()

        // 檢查訂閱狀態
        Task { await checkSubscriptionStatus() }
    }

    nonisolated deinit {
        // Note: updateListenerTask will be cancelled when the object is deallocated
    }

    // MARK: - 載入產品

    func loadProducts() async {
        loadError = nil
        do {
            let productIds = SubscriptionProduct.allCases.map(\.rawValue)
            print("🔍 正在載入產品: \(productIds)")
            let fetched = try await Product.products(for: Set(productIds))
            print("✅ 載入到 \(fetched.count) 個產品")
            for p in fetched {
                print("  - \(p.id): \(p.displayName) \(p.displayPrice)")
            }
            products = fetched.sorted { $0.price < $1.price }
            if products.isEmpty {
                loadError = "App Store 尚未回傳產品。\n可能原因：合約尚未生效（簽完需等數小時）"
            }
        } catch {
            print("❌ 載入產品失敗: \(error)")
            loadError = "載入失敗：\(error.localizedDescription)"
        }
    }

    // MARK: - 購買

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()

            case .userCancelled:
                break

            case .pending:
                purchaseError = "購買待處理中，請稍後再試"

            @unknown default:
                break
            }
        } catch {
            purchaseError = "購買失敗：\(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - 恢復購買

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }

    // MARK: - 檢查訂閱狀態

    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                }
            }
        }

        isSubscribed = hasActiveSubscription
    }

    // MARK: - 開發者無限模式

    /// 開發者模式 — 你自己的手機設為 true 就無限使用
    var isDevMode: Bool {
        // 用 UserDefaults 儲存，啟動一次後永遠有效
        UserDefaults.standard.bool(forKey: "urban_dev_unlimited")
    }

    /// 啟用開發者無限模式（在 App 裡呼叫一次就好）
    func enableDevMode() {
        UserDefaults.standard.set(true, forKey: "urban_dev_unlimited")
    }

    // MARK: - 免費次數管理

    /// 消耗一次免費使用
    func useFreeUse() -> Bool {
        if isSubscribed || isDevMode { return true }

        loadFreeUses()
        if freeUsesRemaining > 0 {
            freeUsesRemaining -= 1
            saveFreeUses()
            return true
        }
        return false
    }

    /// 是否可以使用（訂閱用戶永遠可以，免費用戶看次數）
    var canUse: Bool {
        if isSubscribed || isDevMode { return true }
        loadFreeUses()
        return freeUsesRemaining > 0
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.checkSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - 每日免費次數持久化

    private let freeUsesKey = "urban_free_uses_remaining"
    private let freeUsesDateKey = "urban_free_uses_date"

    private func loadFreeUses() {
        let today = Calendar.current.startOfDay(for: Date())
        let savedDate = UserDefaults.standard.object(forKey: freeUsesDateKey) as? Date ?? .distantPast
        let savedDay = Calendar.current.startOfDay(for: savedDate)

        if today > savedDay {
            // 新的一天，重置次數
            freeUsesRemaining = maxFreeUses
            saveFreeUses()
        } else {
            freeUsesRemaining = UserDefaults.standard.integer(forKey: freeUsesKey)
        }
    }

    private func saveFreeUses() {
        UserDefaults.standard.set(freeUsesRemaining, forKey: freeUsesKey)
        UserDefaults.standard.set(Date(), forKey: freeUsesDateKey)
    }
}

enum StoreError: Error {
    case failedVerification
}
