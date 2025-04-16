//
//  SubscriptionManageable.swift
//  ApphudManager
//
//  Created by USER on 09/04/25.
//

import SwiftUI

@MainActor
protocol SubscriptionManageable: ObservableObject {
    var isActive: Bool { get set }

}
