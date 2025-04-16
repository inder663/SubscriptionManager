//
//  RevenueCatManager.swift
//  ApphudManager
//
//  Created by USER on 07/04/25.
//

import SwiftUI
import RevenueCat


class RevenueCatManager: ObservableObject, ErrorManagable, SubscriptionManageable, LoaderManageable {
    @Published var error: SubscriptionError?
    @Published var isShowError: Bool = false
    @Published var isLoading: Bool = false
    @Published var json: [String: Any]?
    @Published var offerings: Offerings?
    @Published var isActive: Bool = false
    @Published var subscriptionResponse: SubscriptionResponse?
    private let entitlementId: String
    private let key: String
    init(key: String, entitlementId: String, isLogEnabled: Bool = true) {
        self.entitlementId = entitlementId
        self.key = key
        Purchases.logLevel = .debug
    }

    func start() {
        Purchases.configure(withAPIKey: key)
        fetchOffering()
        updateSubscriptionStatus()
    }

    func fetchOffering() {
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
        let allProducts = getAllProducts()
        var products: [SubscriptionPackage] = []
        for product in allProducts {
            let product = product.storeProduct

            let subscrptionPackage: SubscriptionPackage = .init(id: product.productIdentifier, price: .init(price: product.price), duration: getDuration(product: product))
            products.append(subscrptionPackage)
        }
        self.subscriptionResponse?.update(packages: products)
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


    func getAllProducts() -> [Package] {
        return offerings?.current?.availablePackages ?? []
    }

    func purchase(product: SubscriptionPackage) {
        guard let revenuePackage = getAllProducts().first(where: {$0.identifier == product.id }) else {
            let message = "Product not found!"
            self.error = .init(message: message)
            return
        }
        isLoading = true
        Purchases.shared.purchase(package: revenuePackage) {[weak self] (transaction, purchaserInfo, error, userCancelled) in
            self?.isLoading = false
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                return
            }
            self?.updateSubscriptionStatus()
        }
    }

    func updateSubscriptionStatus() {
        Purchases.shared.getCustomerInfo(completion: {[weak self] info, error in
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                return
            }
            guard let info = info else { return }
            self?.isActive = info.entitlements.all[self?.entitlementId ?? ""]?.isActive == true
        })
    }

    func restore() {
        self.isLoading = true
        Purchases.shared.restorePurchases {[weak self] (purchaserInfo, error) in
            self?.isLoading = false
            if let error = error {
                self?.error = .init(message: error.localizedDescription)
                return
            }
            self?.updateSubscriptionStatus()
        }
    }
}

