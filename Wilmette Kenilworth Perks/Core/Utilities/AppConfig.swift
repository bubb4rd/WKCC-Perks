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

    // MARK: - Member auth (backend-first)

    static let chamberAssociationId = 463

    /// Supabase edge function base URL for member OTP auth.
    static let memberAuthBaseURL = URL(
        string: "https://wbzmpylhlsikgzpmfksl.supabase.co/functions/v1/member-auth"
    )!

    /// Supabase edge function base URL for deals, submissions, and admin perks.
    static let perksBaseURL = URL(
        string: "https://wbzmpylhlsikgzpmfksl.supabase.co/functions/v1/perks"
    )!

    /// Publishable/anon key for invoking edge functions from the app.
    /// Safe for client use; never put the service_role key here.
    static let supabaseAnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indiem1weWxobHNpa2d6cG1ma3NsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM3MDk5MzMsImV4cCI6MjA5OTI4NTkzM30.h7DaWwu0gTGqBypcVc_RLEm__1Vhxnb8qfri6QbBfoI"

    // MARK: - Legacy GrowthZone (unused; kept so legacy files compile)

    static let growthZoneHost = "https://wilmettekenilworth.growthzoneapp.com"
    static let growthZoneOAuthClientID = "UNUSED"
    static let oauthScopes = "email openid profile offline_access"
    static let authProxyBaseURL = URL(
        string: "https://REPLACE_WITH_PROJECT.supabase.co/functions/v1/growthzone-auth"
    )!
    static let authCallbackScheme = "wkcc-perks"
    static let authCallbackHost = "auth"

    static var growthZoneHostURL: URL { URL(string: growthZoneHost)! }
    static var growthZoneAuthorizeURL: URL {
        growthZoneHostURL.appending(path: "oauth/authorize")
    }
    static var authCallbackURL: URL {
        URL(string: "\(authCallbackScheme)://\(authCallbackHost)/callback")!
    }

    // MARK: - Auth mode

    static let useMockAuth = false
    static let useMockAdminAccount = false
    static let mockAuthDelaySeconds: UInt64 = 1_200_000_000 // 1.2s

    /// Fixed OTP for local/mock account linking. No email is sent in mock mode.
    static let mockLoginCode = "123123"
}
