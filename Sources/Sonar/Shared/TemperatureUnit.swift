import SwiftUI

enum TemperatureUnit: String {
    case celsius = "C", fahrenheit = "F"

    static let storageKey = "temperatureUnit"
    static var system: TemperatureUnit { Locale.current.measurementSystem == .us ? .fahrenheit : .celsius }
    static var current: TemperatureUnit {
        UserDefaults.standard.string(forKey: storageKey).flatMap(TemperatureUnit.init) ?? system
    }

    /// Sensors report Celsius; convert for display.
    static func convert(_ celsius: Double) -> Double { current == .celsius ? celsius : celsius * 9 / 5 + 32 }

    /// "58 °C" / "136 °F"
    static func format(_ celsius: Double, decimals: Int = 0) -> String {
        "\(convert(celsius).formatted(.number.precision(.fractionLength(decimals)))) °\(current.rawValue)"
    }
}
