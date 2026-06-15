import Foundation

enum AppConfig {
    static let chamberName = "The Wilmette/Kenilworth Chamber of Commerce"
    static let appDisplayName = "WKCC Perks"

    static let chamberStreetAddress = "351 Linden Avenue"
    static let chamberCityStateZip = "Wilmette, IL 60091"
    static let supportEmail = "info@wilmettekenilworth.com"
    static let supportPhone = "847-251-3800"
    static let chamberWebsiteURL = URL(string: "https://www.wilmettekenilworth.com")!

    static var chamberFullAddress: String {
        "\(chamberStreetAddress)\n\(chamberCityStateZip)"
    }

    static var chamberMapsURL: URL {
        URL(string: "https://maps.apple.com/?address=351+Linden+Avenue,Wilmette,IL+60091")!
    }

    static var supportPhoneDialURL: URL? {
        URL(string: "tel:+18472513800")
    }

    static var supportEmailURL: URL? {
        URL(string: "mailto:\(supportEmail)")
    }

    // Replace with real GrowthZone endpoints when chamber provides them.
    static let growthZoneLoginURL = URL(string: "https://www.growthzone.com/login")!
    static let growthZonePasswordResetURL = URL(string: "https://www.growthzone.com/forgot-password")!
    static let authCallbackScheme = "wkcc-perks"
    static let authCallbackHost = "auth"

    static let useMockAuth = true
    static let mockAuthDelaySeconds: UInt64 = 1_200_000_000 // 1.2s

    static var authCallbackURL: URL {
        URL(string: "\(authCallbackScheme)://\(authCallbackHost)/callback")!
    }
}
