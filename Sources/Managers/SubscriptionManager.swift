//
//  SubscriptionManager.swift
//  ApphudManager
//
//  Created by USER on 08/04/25.
//

import SwiftUI
import Combine

@MainActor
@available(iOS 13.0, *)
open class SubscriptionManager: ObservableObject, SubscriptionManageable, LoaderManageable, ErrorManagable {
    @ObservedObject private var apphudManager: ApphudManager
    @ObservedObject private var revenueCatManager: RevenueCatManager
    @Published public var isLoading: Bool = false
    @Published public var isActive: Bool = false
    @Published public var error: SubscriptionError?
    @Published public var isShowError: Bool = false
    @Published public var subscriptionResponse: SubscriptionResponse?
    private let conifuguration: SubscriptionManager.Configuration
    private var cancellable = Set<AnyCancellable>()

    public init(_ configuration: SubscriptionManager.Configuration) {
        self.conifuguration = configuration
        switch configuration.type {
        case .apphud(let key):
            self.apphudManager = ApphudManager(key: key)
            self.revenueCatManager = RevenueCatManager(key: "", entitlementId: "")
            setupApphudBinding()
            apphudManager.start()
        case .revenueCat(let key, let entitlementId):
            self.revenueCatManager = RevenueCatManager(key: key, entitlementId: entitlementId)
            self.apphudManager = ApphudManager(key: "")
            setupRevenueCatBinding()
            revenueCatManager.start()
        }
    }

    private func setupApphudBinding() {
        apphudManager.$isLoading
            .sink { isLoading in
                self.isLoading = isLoading
            }
            .store(in: &cancellable)

        apphudManager.$isActive
            .sink { isActive in
                self.isActive = isActive
            }
            .store(in: &cancellable)

        apphudManager.$isShowError
            .sink { isShowError in
                self.isShowError = isShowError
            }
            .store(in: &cancellable)

        apphudManager.$error
            .sink { error in
                self.error = error
            }
            .store(in: &cancellable)

        apphudManager.$subscriptionResponse
            .sink { subscriptionResponse in
                self.subscriptionResponse = subscriptionResponse
            }
            .store(in: &cancellable)

        apphudManager.objectWillChange.sink { [weak self] (_) in
                  self?.objectWillChange.send()
        }.store(in: &cancellable)

    }

    private func setupRevenueCatBinding() {
        revenueCatManager.$isLoading
            .sink { isLoading in
                debugPrint("IS Loading", isLoading)
                self.isLoading = isLoading
                self.objectWillChange.send()
            }
            .store(in: &cancellable)

        revenueCatManager.$isActive
            .sink { isActive in
                self.isActive = isActive
            }
            .store(in: &cancellable)

        revenueCatManager.$isShowError
            .sink { isShowError in
                self.isShowError = isShowError
            }
            .store(in: &cancellable)


        revenueCatManager.$error
            .sink { error in
                self.error = error
            }
            .store(in: &cancellable)

        revenueCatManager.$subscriptionResponse
            .sink { subscriptionResponse in
                self.subscriptionResponse = subscriptionResponse
            }
            .store(in: &cancellable)

        revenueCatManager.objectWillChange.sink { [weak self] (_) in
                  self?.objectWillChange.send()
        }.store(in: &cancellable)
    }

    public func restoreSubscription() {
        let type = conifuguration.type
        switch type {
        case .apphud(_):
            apphudManager.restore()
        case .revenueCat(_, _):
            revenueCatManager.restore()
        }
    }

   public func purchase(package: SubscriptionPackage) {
        let type = conifuguration.type
        switch type {
        case .apphud(_):
            apphudManager.purchase(product: package)
        case .revenueCat(_, _):
            revenueCatManager.purchase(product: package)
        }
    }

}

public extension SubscriptionManager {
    enum PlatformType {
        case apphud(key: String)
        case revenueCat(key: String, entitlementId: String)
    }
    struct Configuration {
        let type: PlatformType

        public init(type: PlatformType) {
            self.type = type
        }
    }
}
