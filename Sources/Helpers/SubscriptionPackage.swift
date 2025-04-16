//
//  SubscriptionPackage.swift
//  ApphudManager
//
//  Created by USER on 14/04/25.
//

import Foundation
import SwiftUI


// MARK: - Enums

public enum StateType: String, Codable, Sendable {
    case active, normal
}

public enum SubscriptionDuration {
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


    public enum DurationFormat {
        case durationOnly // Week, Month, Year
        case durationAdjective // Weekly, Monthly, Yearly
    }

    public func getDuration(format: DurationFormat) -> String {
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

public struct ComponentBorder: Codable, Sendable {
    public let width: Double
    public let colors: [String]?
}

public struct FontData: Codable, Sendable {
    public let name: String
    public let size: Double
    public let weight: String
}


public struct ComponentStateUI: Codable, Sendable {
    public let foregroundColors: [String]?
    public let backgroundColors: [String]?
    public let border: ComponentBorder?
    public let font: FontData?
    public let cornerRadius: Int?

    public static let `default`: ComponentStateUI = ComponentStateUI(
        foregroundColors: ["#000000"],
        backgroundColors: ["#ffffff"],
        border: nil,
        font: FontData(name: "System", size: 16, weight: "regular"),
        cornerRadius: 0
    )
}

public struct ComponentState: Codable, Sendable {
    public let type: StateType
    public let ui: ComponentStateUI

    public static let `default` = ComponentState(type: .normal, ui: .default)
}

// MARK: - Text & Button

public struct TextComponent: Codable {
    public let id: String
    public let text: String?
    public let image: String?
    public let states: [ComponentState]
}

public struct ComponentButton: Codable {
    public let title: TextComponent?
}

// MARK: - Offer & Package

public struct SubscriptionOffer: Codable {
    public let packId: String
    public let text: String?
}

public struct SubscriptionPrice {
    public let price: Decimal?
}

public struct SubscriptionPackage {
    public let id: String
    public let price: SubscriptionPrice
    public let duration: SubscriptionDuration
    public var displayPrice: String {
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

public struct SubscriptionPaywall {
    public let id: String
    public let identifier: String
    public let packages: [SubscriptionPackage]?
    public let json: [String: Any]?
}

// MARK: - Main Subscription Model

public struct StoreSubscription: Codable {
    public let identifier: String
    public let titles: [String]?
    public let subTitles: [String]?
    public let singlePackText: String?
    public let isShowCloseButton: Bool?
    public let isShowSkipButton: Bool?
    public let offers: [SubscriptionOffer]?

    enum CodingKeys: String, CodingKey {
        case identifier
        case titles
        case subTitles
        case isShowCloseButton
        case singlePackText
        case offers
        case isShowSkipButton
    }


}


// MARK: - Response Container

public struct SubscriptionResponse: Codable {
    public let subscriptions: [StoreSubscription]
    public var packages: [SubscriptionPackage]?

    enum CodingKeys: String, CodingKey {
        case subscriptions
    }

    public mutating func update(packages: [SubscriptionPackage]) {
        self.packages = packages
    }
}

extension SubscriptionResponse {
    public static func decode(from data: [String: Any]) -> SubscriptionResponse? {
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
