//
//  ErrorManagable.swift
//  ApphudManager
//
//  Created by USER on 09/04/25.
//

import SwiftUI

@MainActor
protocol ErrorManagable: ObservableObject {
    var error: SubscriptionError? { get set }
    var isShowError: Bool { get set }
}
