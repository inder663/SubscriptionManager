//
//  LoaderManagable.swift
//  ApphudManager
//
//  Created by USER on 09/04/25.
//

import SwiftUI

@MainActor
protocol LoaderManageable: ObservableObject {
     var isLoading: Bool { get set }
}
