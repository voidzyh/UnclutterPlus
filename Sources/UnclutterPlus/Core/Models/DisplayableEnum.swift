import Foundation

/// Protocol for enums that can provide display names for UI
protocol DisplayableEnum {
    var displayName: String { get }
}