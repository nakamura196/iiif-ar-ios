import Foundation
import StoreKit

@MainActor
class TipJarManager: ObservableObject {
    static let productIDs: [String] = [
        "com.nakamura196.iifar.tip.small",
        "com.nakamura196.iifar.tip.medium",
        "com.nakamura196.iifar.tip.large"
    ]

    @Published var products: [Product] = []
    @Published var isLoading = true
    @Published var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case error(String)
    }

    @Published var loadError: String?

    func loadProducts() async {
        isLoading = true
        loadError = nil
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            products = []
            // Don't show technical error - this is expected in review/sandbox
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    purchaseState = .success
                case .unverified:
                    purchaseState = .error(String(localized: "tipjar_error_unverified", defaultValue: "購入の検証に失敗しました"))
                }
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .error(error.localizedDescription)
        }
    }

    func resetState() {
        purchaseState = .idle
    }

    var emoji: (String, String, String) {
        ("☕️", "🍵", "🎉")
    }
}
