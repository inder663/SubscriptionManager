//
//  RevenueCatManager.swift
//  ApphudManager
//
//  Created by USER on 07/04/25.
//

import SwiftUI
import RevenueCat

@available(iOS 13.0, *)
public class RevenueCatManager: ObservableObject, ErrorManagable, SubscriptionManageable, LoaderManageable {
    @Published public var error: SubscriptionError?
    @Published public var isShowError: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var json: [String: Any]?
    @Published public var offerings: Offerings?
    @Published public var isActive: Bool = false
    @Published public var subscriptionResponse: SubscriptionResponse?
    private let entitlementId: String
    private let key: String
    public init(key: String, entitlementId: String, isLogEnabled: Bool = true) {
        self.entitlementId = entitlementId
        self.key = key
        Purchases.logLevel = .debug
    }

    public func start() {
        Purchases.configure(withAPIKey: key)
        fetchOffering()
        updateSubscriptionStatus()
    }

    public func fetchOffering() {
        isLoading = true
        Purchases.shared.getOfferings {[weak self] (offerings, error) in
            self?.isLoading = false

            self?.updateSubscriptionStatus()
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                return
            }
            self?.offerings = offerings
            if let offerings = offerings {
                self?.json = offerings.current?.metadata as? [String: Any]
                if let data = self?.json {
                    self?.subscriptionResponse = SubscriptionResponse.decode(from: data)
                    self?.loadPackages()
                }
            }
        }
    }

    private func loadPackages() {
        let allStoreProducts = getAllProducts().map { $0.storeProduct }
        for var subscription in subscriptionResponse?.subscriptions ?? [] {
            for subscriptionPack in subscription.packages ?? [] {
                let product = allStoreProducts.first(where: {$0.productIdentifier == subscriptionPack.id})
                if let appStoreProduct = product {
                    if  var subscriptionPack = subscription.packages?.first(where: {$0.id == appStoreProduct.productIdentifier }) {
                        let duration = getDuration(product: appStoreProduct)
                        var price = SubscriptionPrice(price: appStoreProduct.price)

                        var numberFormatter = appStoreProduct.priceFormatter
                        subscriptionPack.update(price: price)
                        subscriptionPack.update(duration: duration)
                        subscriptionPack.update(formatter: numberFormatter)
                        subscription.update(package: subscriptionPack)
                        

                    }
                }
            }
            subscriptionResponse?.update(subscription: subscription)
        }
        self.objectWillChange.send()
    }

    private func getDuration(product: StoreProduct) -> SubscriptionDuration {
        let storeDuration = product.subscriptionPeriod?.unit
        let value = Int(product.subscriptionPeriod?.value ?? 0)
        switch storeDuration {
        case .day:
            return .days(value)
        case .week:
            return .weeks(Double(value))
        case .month:
            return .months(Double(value))
        case .year:
            return .years(Double(value))
        default:
            return .lifetime
        }
    }


    public func getAllProducts() -> [Package] {
        return offerings?.current?.availablePackages ?? []
    }

    public func purchase(product: SubscriptionPackage, completion:((Bool)->Void)?) {
        guard let revenuePackage = getAllProducts().first(where: {$0.storeProduct.productIdentifier == product.id }) else {
            let message = "Product not found!"
            self.error = .init(message: message)
            completion?(false)
            return
        }
        isLoading = true
        Purchases.shared.purchase(package: revenuePackage) {[weak self] (transaction, purchaserInfo, error, userCancelled) in
            self?.isLoading = false
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                completion?(false)
                return
            }
            self?.updateSubscriptionStatus() { isActive in
                completion?(isActive)
            }
        }
    }

    public func updateSubscriptionStatus(completion:((Bool)->Void)? = nil) {
        Purchases.shared.getCustomerInfo(completion: {[weak self] info, error in
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                completion?(false)
                return
            }
            guard let info = info else {
                completion?(false)
                return }
            let isActive = info.entitlements.all[self?.entitlementId ?? ""]?.isActive == true
            self?.isActive = isActive
            completion?(isActive)
        })
    }

    public func restore(completion:((Bool)->Void)?) {
        self.isLoading = true
        Purchases.shared.restorePurchases {[weak self] (purchaserInfo, error) in
            self?.isLoading = false
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                completion?(false)
                return
            }
            self?.updateSubscriptionStatus() { isActive in
                completion?(isActive)
            }
        }
    }
}

