//
//  Untitled.swift
//  ApphudManager
//
//  Created by USER on 05/04/25.
//

import ApphudSDK
import SwiftUI
import StoreKit
import Foundation


@MainActor
@available(iOS 13.0, *)
class ApphudManager: ObservableObject, ErrorManagable, SubscriptionManageable, LoaderManageable {
    @Published var placements: [ApphudPlacement] = []
    @Published var json: [String: Any]?
    @Published var isLoading: Bool = false
    @Published var isActive: Bool = false
    @Published var error: SubscriptionError?
    @Published var isShowError = false
    @Published var subscriptionResponse: SubscriptionResponse?

    private static var appStoreProducts = Set<Product>()

    private var key: String

    init(key: String) {
        self.key = key
    }

    func start() {
        Apphud.start(apiKey: key) {[weak self] user in
            self?.fetchPlacements()
        }
        self.isActive = Apphud.hasActiveSubscription()
    }

    private func fetchPlacements() {
        isLoading = true
        Apphud.fetchPlacements {[weak self] placements, error in
            if let error = error {
                let message = error.localizedDescription
                self?.error = .init(message: message)
            } else {
                self?.placements = placements
                self?.loadAppStoreProducts() {
                    self?.loadJson(from: placements)
                    self?.isLoading = false
                    self?.isActive = Apphud.hasActiveSubscription()

                }


            }
        }
    }

    private func loadJson(from placements: [ApphudPlacement]?) {
        json = placements?.first?.paywall?.json
        if let data = json {
            self.subscriptionResponse = SubscriptionResponse.decode(from: data)
            self.loadPackages()
        }
    }

    private func loadPackages() {
        let allProducts = getAllProducts()
        var products: [SubscriptionPackage] = []
        for product in allProducts {
            guard let product = product.product else {
                return
            }
            let subscrptionPackage: SubscriptionPackage = .init(id: product.id, price: .init(price: product.price), duration: getDuration(product: product))
            products.append(subscrptionPackage)
        }
        self.subscriptionResponse?.update(packages: products)
    }

    private func getDuration(product: Product) -> SubscriptionDuration {
        let storeDuration = product.subscription?.subscriptionPeriod
        switch storeDuration {
        case .everySixMonths:
            return .everySixMonths
        case .everyThreeDays:
            return .everyThreeDays
        case .everyThreeMonths:
            return .everyThreeMonths
        case .everyTwoMonths:
            return .everySixMonths
        case .everyTwoWeeks:
            return .everyTwoWeeks
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        case .none:
            return .lifetime
        case .some(let duration):
            switch duration.unit {
            case .day:
                return .weekly
            case .week:
                return .weekly
            case .month:
                return .monthly
            case .year:
                return .yearly
            @unknown default:
                return .lifetime
            }

        }
    }


    func getPlacement(id: String) -> ApphudPlacement? {
        placements.first(where: {$0.identifier == id})
    }

    func getProducts(of placement: ApphudPlacement) -> [ApphudProduct] {
        placement.paywall?.products ?? []
    }

    func getPaywall(of placement: ApphudPlacement) -> ApphudPaywall? {
        placement.paywall
    }

    func getAllProducts() -> [ApphudProduct] {
        placements
            .compactMap{$0.paywall?.products}
            .flatMap{$0}
    }

    func loadAppStoreProducts(completion: @escaping ()->Void) {
        let dispatchGroup = DispatchGroup()
        for product in getAllProducts() {
            dispatchGroup.enter()
            Task {
                defer { dispatchGroup.leave() }
                if let appStoreProduct = try? await product.product() {
                    ApphudManager.appStoreProducts.insert(appStoreProduct)
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    static func getAppStoreProduct(of appHudProduct: ApphudProduct) -> Product? {
        var product = ApphudManager.appStoreProducts.first(where: { $0.id == appHudProduct.productId })
        if product == nil {
            Task {
                product = try? await appHudProduct.product()
            }
            if product == nil {
                sleep(2)
            }
        }
        return product
    }

    func getAppStoreProduct(of subscriptionPackage: SubscriptionPackage) -> Product? {
        guard
            let apphudProduct = getAllProducts().first(where: {$0.productId == subscriptionPackage.id}),
            let appStoreProduct = ApphudManager.getAppStoreProduct(of: apphudProduct) else { return nil }
        return appStoreProduct
    }

    func getAllPlacements() -> [ApphudPlacement] {
        return placements
    }

    // Purchase

    func purchase(product: SubscriptionPackage) {
        guard let apphudProduct = getAllProducts().first(where: {$0.productId == product.id})  else {
            let message = "Product not found!"
            self.error = .init(message: message)
            return
        }
        isLoading = true
        Apphud.purchase(apphudProduct) {[weak self] result in
            self?.isLoading = false
            if let subscription = result.subscription, subscription.isActive(){
                self?.isActive = true
            } else if let purchase = result.nonRenewingPurchase, purchase.isActive(){
                self?.isActive = true
            } else {
                let message = result.error?.localizedDescription ?? "Purchase failed!"
                self?.error = .init(message: message)
            }
        }
    }

    func restore() {
        isLoading = true
        Apphud.restorePurchases {[weak self] _, _, error in
            self?.isLoading = false
            if let error = error {
                let message = error.localizedDescription
                self?.error = .init(message: message)
            }
            self?.isActive = Apphud.hasActiveSubscription()
        }
    }

}

@MainActor
extension ApphudProduct {
    var product: Product? {
        ApphudManager.getAppStoreProduct(of: self)
    }

    enum DurationFormat {
        case durationOnly // Week, Month, Year
        case durationAdjective // Weekly, Monthly, Yearly
    }

    func getDuration(format: DurationFormat) -> String {
        var unit = ""
        guard let product = product else { return unit }
        switch product.subscription?.subscriptionPeriod {
        case .everySixMonths:
            return "Every 6 months"
        case .everyThreeDays:
            return  "Every 3 days"
        case .everyThreeMonths:
            return "Every 3 months"
        case .everyTwoMonths:
            return  "Every 2 months"
        case .everyTwoWeeks:
            unit = format == .durationOnly ? "Weeks" : "Every 2 weeks"
        case .weekly:
            unit = format == .durationOnly ? "Week" : "Weekly"
        case .monthly:
            unit = format == .durationOnly ? "Month" : "Monthly"
        case .yearly:
            unit = format == .durationOnly ? "Year" : "Yearly"
        default:
            unit = format == .durationOnly ? "Lifetime" : "Lifetime"
        }
        return unit
    }

    func getPriceText(format: DurationFormat, isWeekly: Bool = false) -> String {
        return product?.displayPrice ?? ""
    }

    //    func getProductWeeklyPrice() -> String {
    //        guard let product else { return "" }
    //        let price = product.price
    //        let numberFormatter = NumberFormatter()
    //        numberFormatter.numberStyle = .currency
    //        numberFormatter.locale = .current
    //
    //        var divideBy: Double = 1
    //        let u = Double(product.subscription?.subscriptionPeriod.value ?? 1)
    //        switch product.subscription?.subscriptionPeriod {
    //        case .everySixMonths:
    //            divideBy = Double(4.34 * 6 * u)
    //        case .everyThreeDays:
    //            // Assuming the price is for monthly or yearly subscription and you want to scale down accordingly
    //            divideBy = Double(4.34 * 365 / 3 * u) // 365 days / 3 days = 121.67 periods per year
    //        case .everyThreeMonths:
    //            divideBy = Double(4.34 * 4 * u) // 4 quarters in a year
    //
    //        case .everyTwoMonths:
    //            divideBy = Double(4.34 * 6 * u) // 6 periods per year
    //        case .everyTwoWeeks:
    //            divideBy = Double(4.34 * 26 * u) // 26 periods per year (52 weeks / 2)
    //        case .weekly:
    //            divideBy = Double(4.34 * 52 * u) // 52 weeks in a year
    //        case .monthly:
    //            divideBy = Double(4.34 * 12 * u) // 12 months in a year
    //        case .yearly:
    //            divideBy = Double(4.34 * u) // 1 period per year
    //        default:
    //            divideBy = 1
    //        }
    //
    //        let weeklyPrice = price / Decimal(divideBy)
    //
    //        let priceString = numberFormatter.string(from: NSNumber(value: weeklyPrice.doubleValue))
    //        return priceString ?? ""
    //    }
}

extension Decimal {
    var doubleValue:Double {
        return NSDecimalNumber(decimal:self).doubleValue
    }
}
