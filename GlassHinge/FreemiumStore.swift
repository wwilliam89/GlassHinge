//
//  FreemiumStore.swift
//  GlassHinge
//
//  Free-launch monetization scaffold, per the launch plan: ship v1 as a
//  fully free app, then add paid Pro features via In-App Purchase later
//  without restructuring the app.
//
//  v1 (this release): everything free. `isProUnlocked` always returns true
//  so no purchase UI is shown and App Review sees a plain free app.
//
//  To turn on paid Pro in v1.1: (1) create the product IDs below in
//  App Store Connect (Subscriptions or Non-Consumable), (2) flip
//  `monetizationEnabled` to true, (3) resubmit. StoreKit 2 handles the
//  rest; transactions verify through StoreKit only — no server needed.
//

import Foundation
import StoreKit

@MainActor
final class FreemiumStore: ObservableObject {

    /// Flip to true in the v1.1 release to start charging for Pro.
    static let monetizationEnabled = false

    enum ProductID {
        /// One-time unlock. Alternate: a Pro subscription product.
        static let proUnlock = "com.glasshinge.mac.pro.unlock"
    }

    @Published private(set) var isProUnlocked: Bool = true
    @Published private(set) var products: [Product] = []

    func load() async {
        guard Self.monetizationEnabled else { return }
        do {
            let storeProducts = try await Product.products(for: [ProductID.proUnlock])
            products = storeProducts
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productID == ProductID.proUnlock else { continue }
                isProUnlocked = true
                await transaction.finish()
            }
        } catch {
            // Monetization disabled in v1; nothing to surface to the user.
        }
    }

    func purchasePro() async throws {
        guard let product = products.first else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return }
            isProUnlocked = true
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
}
