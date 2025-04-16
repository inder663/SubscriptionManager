//
//  SubscriptionPackage.swift
//  ApphudManager
//
//  Created by USER on 14/04/25.
//

import Foundation
import SwiftUI


// MARK: - Enums

enum StateType: String, Codable {
    case active, normal
}

enum SubscriptionDuration {
    case weekly, monthly, yearly, lifetime
    case days(Int)
    case months(Double)
    case weeks(Double)
    case years(Double)
    case everySixMonths
    case everyThreeDays
    case everyThreeMonths
    case everyTwoMonths
    case everyTwoWeeks


    enum DurationFormat {
        case durationOnly // Week, Month, Year
        case durationAdjective // Weekly, Monthly, Yearly
    }

    func getDuration(format: DurationFormat) -> String {
        var unit = ""
        switch self {
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
        case .days( _):
            unit = format == .durationOnly ? "Day" : "Daily"
        case .months( _):
            unit = format == .durationOnly ? "Month" : "Monthly"
        case .weeks( _):
            unit = format == .durationOnly ? "Week" : "Weekly"
        case .years( _):
            unit = format == .durationOnly ? "Year" : "Yearly"
        default:
            unit = format == .durationOnly ? "Lifetime" : "Lifetime"
        }
        return unit
    }


}



// MARK: - UI Models

struct ComponentBorder: Codable {
    let width: Double
    let colors: [String]?
}

struct FontData: Codable {
    let name: String
    let size: Double
    let weight: String
}

struct ComponentStateUI: Codable {
    let foregroundColors: [String]?
    let backgroundColors: [String]?
    let border: ComponentBorder?
    let font: FontData?
    let cornerRadius: Int?

    static let `default`: ComponentStateUI = ComponentStateUI(
        foregroundColors: ["#000000"],
        backgroundColors: ["#ffffff"],
        border: nil,
        font: FontData(name: "System", size: 16, weight: "regular"),
        cornerRadius: 0
    )
}

struct ComponentState: Codable {
    let type: StateType
    let ui: ComponentStateUI

    static let `default` = ComponentState(type: .normal, ui: .default)
}

// MARK: - Text & Button

struct TextComponent: Codable {
    let id: String
    let text: String?
    let image: String?
    let states: [ComponentState]
}

struct ComponentButton: Codable {
    let title: TextComponent?
}

// MARK: - Offer & Package

struct SubscriptionOffer: Codable {
    let packId: String
    let text: String?
}

struct SubscriptionPrice {
    let price: Decimal?
}

struct SubscriptionPackage {
    let id: String
    let price: SubscriptionPrice
    let duration: SubscriptionDuration
    var displayPrice: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = .current
        
        if let priceDecimal = price.price {
            let priceString = numberFormatter.string(from: NSNumber(value: priceDecimal.doubleValue)) ?? "-"
            let duration = duration.getDuration(format: .durationAdjective)
            return priceString + "/" + duration
        }
        return ""
    }
}

// MARK: - Paywall Placeholder

struct SubscriptionPaywall {
    let id: String
    let identifier: String
    let packages: [SubscriptionPackage]?
    let json: [String: Any]?
}

// MARK: - Main Subscription Model

struct Subscription: Codable {
    let identifier: String
    let titles: [String]?
    let subTitles: [String]?
    let singlePackText: String?
    let isShowCloseButton: Bool?
    let offers: [SubscriptionOffer]?

    enum CodingKeys: String, CodingKey {
        case identifier
        case titles
        case subTitles
        case isShowCloseButton
        case singlePackText
        case offers
    }


}


// MARK: - Response Container

struct SubscriptionResponse: Codable {
    let subscriptions: [Subscription]
    var packages: [SubscriptionPackage]?

    enum CodingKeys: String, CodingKey {
        case subscriptions
    }

    mutating func update(packages: [SubscriptionPackage]) {
        self.packages = packages
    }
}

extension SubscriptionResponse {
    static func decode(from data: [String: Any]) -> SubscriptionResponse? {
        do {

            // 2. Convert to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])

            // 3. Decode to Swift object
            let decoder = JSONDecoder()
            let result = try decoder.decode(SubscriptionResponse.self, from: jsonData)
            return result
        } catch {
            print("❌ Failed to decode subscriptions:", error)
            return nil
        }
    }
}
