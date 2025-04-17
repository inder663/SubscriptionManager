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
public class ApphudManager: ObservableObject, ErrorManagable, SubscriptionManageable, LoaderManageable {
    @Published public var placements: [ApphudPlacement] = []
    @Published public var json: [String: Any]?
    @Published public var isLoading: Bool = false
    @Published public var isActive: Bool = false
    @Published public var error: SubscriptionError?
    @Published public var isShowError = false
    @Published public var subscriptionResponse: SubscriptionResponse?

    @Published private var paywallJsons:[String:[String:Any]] = [:]

    private static var appStoreProducts = Set<Product>()

    private var key: String

    public init(key: String) {
        self.key = key
    }

    public func start() {
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
        for placement in self.placements {
            let paywall = placement.paywall
            let paywallId = paywall?.identifier ?? "none"
            let json = paywall?.json
            self.paywallJsons[paywallId] = json
        }

        var collectiveJson: [[String: Any]] = []
        for (key,value) in paywallJsons {
            collectiveJson.append(value)
        }
        json = [
            "styles": collectiveJson.first?["styles"],
            "subscriptions":collectiveJson
        ]



        if let data = json {
            self.subscriptionResponse = SubscriptionResponse.decode(from: data)
            self.loadPackages()
        }
    }

    private func loadPackages() {
        let allPaywalls = placements.map({$0.paywall})
        for paywall in allPaywalls {
            if var subscription = subscriptionResponse?.subscriptions.first(where: {$0.identifier == paywall?.identifier}), let products = paywall?.products {
                for product in products {
                    if let appStoreProduct = product.product {
                        if  var subscriptionPack = subscription.packages?.first(where: {$0.id == appStoreProduct.id }) {
                            let duration = getDuration(product: appStoreProduct)
                            let price: SubscriptionPrice = .init(price: appStoreProduct.price)
                            subscriptionPack.update(price: price)
                            subscriptionPack.update(duration: duration)
                            subscription.update(package: subscriptionPack)
                            subscriptionResponse?.update(subscription: subscription)
                        }
                    }
                }

            }
        }
        self.objectWillChange.send()
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


    public func getPlacement(id: String) -> ApphudPlacement? {
        placements.first(where: {$0.identifier == id})
    }

    public func getProducts(of placement: ApphudPlacement) -> [ApphudProduct] {
        placement.paywall?.products ?? []
    }

    public func getPaywall(of placement: ApphudPlacement) -> ApphudPaywall? {
        placement.paywall
    }

    public func getAllProducts() -> [ApphudProduct] {
        placements
            .compactMap{$0.paywall?.products}
            .flatMap{$0}
    }

    public func loadAppStoreProducts(completion: @escaping ()->Void) {
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

    public func getAppStoreProduct(of subscriptionPackage: SubscriptionPackage) -> Product? {
        guard
            let apphudProduct = getAllProducts().first(where: {$0.productId == subscriptionPackage.id}),
            let appStoreProduct = ApphudManager.getAppStoreProduct(of: apphudProduct) else { return nil }
        return appStoreProduct
    }

    public func getAllPlacements() -> [ApphudPlacement] {
        return placements
    }

    // Purchase
    
    public func purchase(product: SubscriptionPackage, completion:((Bool)->Void)?) {
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
                completion?(true)
            } else if let purchase = result.nonRenewingPurchase, purchase.isActive(){
                self?.isActive = true
                completion?(true)
            } else {
                completion?(false)
                let message = result.error?.localizedDescription ?? "Purchase failed!"
                self?.error = .init(message: message)
            }
        }
    }

    public func restore(completion:((Bool)->Void)?) {
        isLoading = true
        Apphud.restorePurchases {[weak self] _, _, error in
            self?.isLoading = false
            if let error = error {
                let message = error.localizedDescription
                self?.error = .init(message: message)
            }
            let isActive = Apphud.hasActiveSubscription()
            self?.isActive = isActive
            completion?(isActive)
        }
    }

}

@MainActor
extension ApphudProduct {
    public var product: Product? {
        ApphudManager.getAppStoreProduct(of: self)
    }

    public enum DurationFormat {
        case durationOnly // Week, Month, Year
        case durationAdjective // Weekly, Monthly, Yearly
    }

    public func getDuration(format: DurationFormat) -> String {
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

}

extension Decimal {
    public var doubleValue:Double {
        return NSDecimalNumber(decimal:self).doubleValue
    }
}
