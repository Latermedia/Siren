//
//  Rules.swift
//  Siren
//
//  Created by Sabintsev, Arthur on 11/18/18.
//  Copyright © 2018 Sabintsev iOS Projects. All rights reserved.
//

import Foundation

/// Alert Presentation Rules for Siren.
public class Rules {
    /// The type of alert that should be presented.
    fileprivate(set) var alertType: AlertType

    /// The frequency in which a the user is prompted to update the app
    /// once a new version is available in the App Store and if they have not updated yet.
    let frequency: UpdatePromptFrequency

    /// Initializes the alert presentation rules.
    ///
    /// - Parameters:
    ///   - frequency: How often a user should be prompted to update the app once a new version is available in the App Store.
    ///   - alertType: The type of alert that should be presented.
    public init(promptFrequency frequency: UpdatePromptFrequency,
                forAlertType alertType: AlertType) {
        self.frequency = frequency
        self.alertType = alertType
    }

    /// Performs a version check immediately, but allows the user to skip updating the app until the next time the app becomes active.
    public static var annoying: Rules {
        return Rules(promptFrequency: .immediately, forAlertType: .option)
    }

    /// Performs a version check immediately and forces the user to update the app.
    public static var critical: Rules {
        return Rules(promptFrequency: .immediately, forAlertType: .force)
    }

    /// Performs a version check once a day, but allows the user to skip updating the app until
    /// the next time the app becomes active or skipping the update all together until another version is released.
    ///
    /// This is the default setting.
    public static var `default`: Rules {
        return Rules(promptFrequency: .daily, forAlertType: .skip)
    }

    /// Performs a version check weekly, but allows the user to skip updating the app until the next time the app becomes active.
    public static var hinting: Rules {
        return Rules(promptFrequency: .weekly, forAlertType: .option)
    }

    /// Performs a version check daily, but allows the user to skip updating the app until the next time the app becomes active.
    public static var persistent: Rules {
        return Rules(promptFrequency: .daily, forAlertType: .option)
    }

    /// Performs a version check weekly, but allows the user to skip updating the app until
    /// the next time the app becomes active or skipping the update all together until another version is released.
    public static var relaxed: Rules {
        return Rules(promptFrequency: .weekly, forAlertType: .skip)
    }
}

// Rules-related Constants
public extension Rules {
    /// Determines the type of alert to present after a successful version check has been performed.
    enum AlertType {
        /// Forces the user to update your app (1 button alert).
        case force
        /// Presents the user with option to update app now or at next launch (2 button alert).
        case option
        /// Presents the user with option to update the app now, at next launch, or to Skip This Version all together (3 button alert).
        case skip
        /// Doesn't present the alert.
        /// Use this option if you would like to present a custom alert to the end-user.
        case none
    }

    /// Determines the frequency in which the user is prompted to update the app
    /// once a new version is available in the App Store and if they have not updated yet.
    enum UpdatePromptFrequency: UInt {
        /// Version check performed every time the app is launched.
        case immediately = 0
        /// Version check performed once a day.
        case daily = 1
        /// Version check performed once a week.
        case weekly = 7
    }
}
/// Global conditional rules that fires if currently installed version is back certain number of releases. Applicable to all Update types
public class GlobalConditionalRules: Rules {
    private typealias SemanticVersion = (major: Int, minor: Int, patch: Int, revision: Int)
    /// Numbers of releases the alert will give an option to update next time
    private let voluntary: Int
    /// Numbers of releases the alert will force to update
    private let involuntary: Int
    /// Numbers of major releases the alert will force to update
    private let majorInvoluntary: Int
    
    /// Initializes the alert presentation with conditional rules. Default alert type for conditinal rules is .none
    /// - Parameters:
    ///   - frequency: How often a user should be prompted to update the app once a new version is available in the App Store.
    ///   - voluntary: Look for number of versions when to give option to update
    ///   - involuntary: Look for number of versions when to force to update
    public init(promptFrequency: UpdatePromptFrequency, voluntary: Int, involuntary: Int, majorInvoluntary: Int) {
        self.voluntary = voluntary
        self.involuntary = involuntary
        self.majorInvoluntary = majorInvoluntary
        super.init(promptFrequency: promptFrequency, forAlertType: .none)
    }
    
    /// Modifies alert type if the currently installed version falls into condition
    /// - Parameters:
    ///   - currentInstalledVersion: currently installed app version on the device
    ///   - currentAppStoreVersion: currently available app version in the AppStore
    public func apply(currentInstalledVersion: String, currentAppStoreVersion: String) {
        guard let installedVersion = try? normalizeVersion(currentInstalledVersion),
              let appStoreVersion = try? normalizeVersion(currentAppStoreVersion) else { return }
        // Force to update if AppStore major version is newer
        if appStoreVersion.major > installedVersion.major {
            // The installed version is 1 release behind
            if appStoreVersion.major - installedVersion.major == 1 {
                // Force to update if AppStore version is beyoud majorInvoluntary
                if appStoreVersion.minor >= majorInvoluntary {
                    alertType = .force
                } else {
                    alertType = .none
                }
            // Force to update if the installed major version is more than 1 release behind
            } else {
                alertType = .force
            }
        // Force to update if AppStore minor version is older then given involuntary requirement
        } else if installedVersion.minor + involuntary <= appStoreVersion.minor {
            alertType = .force
        // Offer to update if AppStore minor version is older then given voluntary requirement
        } else if installedVersion.minor + voluntary <= appStoreVersion.minor {
            alertType = .option
        } else {
        // Don't show an alert if the currently installed app is newer than given voluntary limit
            alertType = .none
        }
    }
    
    /// Convert String representation of a version into SemanticVersion
    /// - Parameter version: String representation of a version
    /// - Returns: Converted String into SemanticVersion
    private func normalizeVersion(_ version: String) throws -> SemanticVersion {
        var components = DataParser.split(version: version)
        guard !components.isEmpty else { throw KnownError.appStoreVersionArrayFailure }
        // Fullfill if the passed version misses parts
        while components.count < 4 { components.append(0) }
        // Since components fullfilled it is safe to access by index
        let major = components[0]
        let minor = components[1]
        let patch = components[2]
        let revision = components[2]

        return (major: major, minor: minor, patch: patch, revision: revision)
    }
}
