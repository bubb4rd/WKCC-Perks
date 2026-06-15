# WKCC Hybrid Member Deals App Context Document

## Project overview

This project is a companion mobile app for a Chamber of Commerce that will let members log in, browse participating businesses, and access member-exclusive deals, coupons, and perks. The chamber website is managed in WordPress, while member authentication and member portal functionality are handled through ChamberMaster/GrowthZone, so the app should follow a hybrid architecture that keeps GrowthZone as the system of record for identity and membership status rather than creating a separate account system.[cite:58][cite:59][cite:66]

The first release should prioritize a reliable login experience, a clear member-only deals flow, and low administrative overhead. GrowthZone documents support for Single Sign-On and APIs, which makes it possible to design the app around existing chamber credentials and avoid duplicating membership logic in the mobile app.[cite:55][cite:58][cite:59]

## Product goals

The app should support four primary user goals:

- Sign in with an existing chamber member login.
- View member-only deals and perks from participating chamber businesses.
- Browse a directory of participating businesses and read the benefit details tied to each one.
- Present a simple, trustworthy experience that feels consistent with the chamber brand and existing website.

The first version does not need to be a full replacement for the website or member portal. A hybrid approach is more appropriate because chambers commonly connect GrowthZone functionality into their websites rather than rebuilding all membership features from scratch, and GrowthZone provides both hosted login patterns and API integration paths.[cite:57][cite:59][cite:61][cite:66]

## Confirmed project context

The following context has already been established for the project and should be treated as working assumptions unless the chamber changes direction:

- The chamber website runs on WordPress.
- Member login already exists through ChamberMaster/GrowthZone.
- The app direction is hybrid, not fully native-auth from scratch.
- The chamber wants member-exclusive offers, deals, coupons, and perks from participating businesses.
- The prior idea was lightweight rather than highly complex; examples discussed include offers like 20% off a purchase or a free gift with purchase.
- A relevant reference pattern is the Women Belong deals page, which presents current member offers in a browsable format and ties deal visibility to membership value messaging.[cite:40][cite:41]

## Recommended system architecture

The recommended architecture is:

1. **WordPress** remains the public website and content layer for chamber information, FAQs, general branding pages, and any public landing pages related to the app.
2. **GrowthZone/ChamberMaster** remains the source of truth for authentication, member status, and existing member identity.
3. **Swift iOS app** provides the mobile user experience layer, including login entry, deals browsing, business listings, and saved/redemption states.
4. **Lightweight chamber content service or admin-friendly data source** stores or exposes deals, participating businesses, categories, expiration dates, terms, and redemption instructions if GrowthZone is not used directly for all deal content.

This structure is aligned with GrowthZone’s documented role as an association management system with SSO and API integrations and avoids creating a duplicate user database in the app.[cite:55][cite:58][cite:59]

## Authentication strategy

### Preferred login model

The app should use the existing GrowthZone member login rather than building a separate registration and password system. GrowthZone explicitly documents Single Sign-On for connected systems and also provides APIs for integrating GrowthZone data into other systems.[cite:55][cite:58][cite:59]

### Recommended phased approach

#### Phase 1: Hosted login inside a secure app flow

Use the existing GrowthZone login page in a secure browser-based authentication flow, preferably `ASWebAuthenticationSession` on iOS rather than a basic embedded webview. This approach is the fastest path because it reuses the chamber’s current credentials and reduces security risk from handling passwords directly in the app; it also fits the existing GrowthZone hosted login model.[cite:57][cite:64]

Implementation expectation for the Cursor agent:

- Create a login entry screen in SwiftUI.
- Tapping **Member Login** launches a secure web authentication session to the chamber’s GrowthZone/ChamberMaster login endpoint.
- On successful login, the app receives a redirect or session-confirmation result.
- The app exchanges that result for an internal app session and loads member-only content.
- If GrowthZone cannot support direct callback-style app auth in the chamber’s current setup, begin with a browser handoff plus mobile-friendly authenticated web portal screens for protected content.

#### Phase 2: SSO-backed native session

If the chamber has SSO enabled and the vendor can provide the required configuration, the app should move toward an SSO-backed sign-in flow so the app can establish a true native session while GrowthZone remains the identity provider. GrowthZone’s documentation states that SSO is intended to reduce friction across connected systems and improve security when users navigate between systems.[cite:55][cite:58]

#### Phase 3: API-assisted member validation

If API access is available, the app can validate membership status, account type, company association, and possibly rep-level information more directly. GrowthZone states that APIs can be used to integrate GrowthZone data into other systems, which is the long-term path for a more refined app experience.[cite:59][cite:62]

## Why hybrid is the right choice

A hybrid model is the best fit for this project because it reduces cost, shortens delivery time, and keeps member credentials under the existing chamber system. It also avoids the common failure point of small membership apps: trying to rebuild authentication, profile management, renewals, and entitlement logic too early.[cite:55][cite:58][cite:59]

The tradeoff is that some user flows may remain partly web-based at first, especially around login, password reset, or portal-only features. That limitation is acceptable for version 1 as long as the high-value screens such as deals, businesses, and member benefit details feel native and easy to use.[cite:57][cite:65]

## Core app modules

### 1. Authentication module

Responsibilities:

- Launch member sign-in.
- Detect whether a user has an active authenticated session.
- Store app session state securely.
- Handle sign-out.
- Route unauthenticated users away from member-only screens.

Recommended iOS implementation:

- SwiftUI for login screen and session-aware navigation.
- `ASWebAuthenticationSession` for secure login handoff.
- Keychain storage for tokens or session identifiers if the final GrowthZone auth flow returns app-usable credentials.
- An `AuthManager` service object that is the single source of truth for authentication state in the app.

### 2. Member identity and entitlement module

Responsibilities:

- Determine whether the user is a valid current member.
- Map that member to permissions such as `canViewDeals`, `canSaveDeals`, `canRedeemDeals`, or `businessAdmin`.
- Optionally support multiple users from one member business if the chamber eventually allows employee access.

Recommended data model:

- `MemberProfile`
- `MembershipStatus`
- `CompanyProfile`
- `MemberEntitlements`

This should never become a second member database managed manually inside the app. GrowthZone should remain the source of truth where possible.[cite:59]

### 3. Deals module

Responsibilities:

- Show all active member-exclusive offers.
- Allow filtering by category, business, popularity, or expiration date.
- Render benefit details such as offer title, business name, description, fine print, redemption method, expiration, and eligibility.
- Support flags such as `featured`, `new`, `expiringSoon`, and `membersOnly`.

Reference direction:

Women Belong’s deals page is a useful benchmark because it presents current offers in a browseable member-benefit context rather than as a complex e-commerce system.[cite:40][cite:41]

### 4. Participating businesses module

Responsibilities:

- Show the list of businesses offering benefits.
- Display business logo, category, short description, location, contact info, and current offers.
- Support search and category filters.
- Let users tap from a business profile into one or more available deals.

### 5. Redemption and proof-of-membership module

Responsibilities:

- Display deal redemption instructions clearly.
- Support simple redemption methods in v1, such as “show this screen,” “use this code,” or “mention your chamber membership.”
- Optionally show a digital member card or proof-of-membership badge if the chamber wants to modernize old physical member-exclusive cards.

### 6. Content and admin synchronization module

Responsibilities:

- Fetch deals and business data from the designated source.
- Cache non-sensitive content for performance.
- Refresh time-sensitive content on launch and foreground resume.
- Respect offer start dates, end dates, and disabled states.

## Recommended Swift app architecture

### UI framework

Use **SwiftUI** as the primary UI layer for faster iteration, modern navigation patterns, and maintainable state-driven screens.

### App architecture pattern

Use MVVM with service layers:

- `Views`: SwiftUI screens.
- `ViewModels`: screen state, loading state, search/filter state, and interaction logic.
- `Services`: auth, API, content sync, analytics, logging.
- `Models`: member, business, deal, session, entitlement, app config.

Suggested top-level structure:

```text
WKCCApp/
  App/
    WKCCApp.swift
    AppRouter.swift
  Core/
    Networking/
    Auth/
    Storage/
    DesignSystem/
    Utilities/
  Features/
    Auth/
    Home/
    Deals/
    Businesses/
    Profile/
    Settings/
  Models/
  Services/
```

### State handling

Use a root app state object with at least these high-level states:

- `launching`
- `unauthenticated`
- `authenticating`
- `authenticated`
- `error`

The router should send users to the correct flow based on session validity and whether membership entitlements have been loaded.

## Explicit implementation steps for Cursor

### Step 1: Build the project shell

Create a new SwiftUI iOS app with:

- Tab-based navigation or a home-plus-stack pattern.
- Basic branding placeholders using the chamber logo.
- Dark mode support.
- A central design token file for colors, spacing, typography, border radius, and shadows.

### Step 2: Build the app router

Create a root router that decides which experience to show:

- Splash/loading screen.
- Sign-in screen if no valid session exists.
- Main member app if a session exists and the user is entitled.
- Restricted-access screen if sign-in succeeds but membership is not active.

### Step 3: Implement the authentication layer

Create:

- `AuthManager`
- `AuthSession`
- `LoginViewModel`
- `KeychainStore`

Minimum capabilities:

- Start login flow.
- Observe login completion.
- Persist session securely.
- Restore session on app relaunch.
- Sign out and clear secure data.
- Launch password reset in browser when needed.

### Step 4: Create the domain models

Define Codable models such as:

```swift
struct MemberProfile: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let membershipStatus: String
    let companyId: String?
    let companyName: String?
}

struct ChamberBusiness: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let shortDescription: String
    let logoURL: URL?
    let websiteURL: URL?
    let phone: String?
    let address: String?
    let activeDeals: [DealSummary]
}

struct DealSummary: Codable, Identifiable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let shortDescription: String
    let expirationDate: Date?
    let isFeatured: Bool
}

struct DealDetail: Codable, Identifiable {
    let id: String
    let title: String
    let businessId: String
    let businessName: String
    let description: String
    let terms: String?
    let redemptionInstructions: String
    let startDate: Date?
    let expirationDate: Date?
    let category: String
    let imageURL: URL?
    let membersOnly: Bool
}
```

### Step 5: Build placeholder data flows first

Before final backend integration, create a mock data layer so product flows can be tested quickly. Include example offers such as:

- 20% off purchase.
- Free gift with purchase.
- Members-only event perk.
- Discounted consultation or introductory session.

These examples are consistent with the chamber’s stated concept direction and similar member-benefit patterns already discussed.[cite:40][cite:41]

### Step 6: Build the core screens

Minimum screen list:

- Splash screen.
- Welcome/login screen.
- Home screen.
- Deals list.
- Deal detail.
- Businesses list.
- Business detail.
- Profile/account screen.
- Help/support screen.
- Not-authorized or inactive-membership screen.

### Step 7: Create the home experience

The home screen should include:

- Greeting with member name.
- Featured deals carousel or horizontal section.
- Browse by category.
- Participating businesses preview.
- Expiring soon deals.
- Optional digital member card shortcut.

### Step 8: Add search and filters

Deals and businesses should support at minimum:

- Search by title or business.
- Category filters.
- “Expiring soon.”
- “Featured.”
- “Near me” can be postponed unless accurate business location data exists.

### Step 9: Design the business and deal relationship clearly

Each business detail page should show:

- Logo and name.
- Chamber-partner identity.
- About section.
- Current active offers.
- Contact or website actions.
- Redemption notes if the business has special rules.

Each deal detail page should show:

- Deal title.
- Participating business.
- Full description.
- Terms and exclusions.
- Expiration date.
- Redemption method.
- Save/share action if allowed.

### Step 10: Define the backend integration contract

Cursor should prepare the app so the data source can be swapped later with minimal UI changes. Use protocol-based services such as:

```swift
protocol AuthServicing {
    func startLogin() async throws
    func restoreSession() async -> AuthSession?
    func signOut() async
}

protocol DealsServicing {
    func fetchDeals() async throws -> [DealSummary]
    func fetchDeal(id: String) async throws -> DealDetail
}

protocol BusinessServicing {
    func fetchBusinesses() async throws -> [ChamberBusiness]
    func fetchBusiness(id: String) async throws -> ChamberBusiness
}
```

### Step 11: Prepare for hybrid content delivery

There are several realistic hybrid content sources:

- GrowthZone API, if available.[cite:59]
- WordPress custom post types exposed through the WordPress REST API.
- A lightweight middleware service that aggregates GrowthZone member status plus chamber-managed deal content.
- A manually maintained JSON feed during prototype development.

The app should be coded so any of these can sit behind the service layer.

### Step 12: Build security-aware fallbacks

If the login flow cannot yet return a clean native session token, Cursor should support these fallback patterns:

- Open protected member pages in a secure in-app browser after login.
- Keep native browsing for public or lightly protected data.
- Gate member-only data behind a simple app session flag driven by successful authentication.

This is not the ideal long-term state, but it is a practical bridge for version 1.[cite:55][cite:57][cite:65]

## Data ownership recommendations

### Use GrowthZone for

- Authentication.
- Member identity.
- Membership status.
- Possibly company/member relationship data.

### Use WordPress or a chamber-managed content source for

- Public app information pages.
- FAQs.
- Marketing copy.
- Possibly deals and business content if chamber staff need a simple editing workflow.

### Consider a middleware layer if needed for

- Mapping GrowthZone members to app entitlements.
- Merging deal data with business data.
- Normalizing inconsistent data.
- Logging redemptions or app-specific analytics.

## Admin and content workflow suggestions

The chamber will need a lightweight operations workflow, not just an app. The app will only stay current if someone can easily add, edit, expire, and remove deals.

Recommended content fields for each deal:

- Deal title.
- Participating business.
- Category.
- Short summary.
- Full description.
- Terms and exclusions.
- Redemption instructions.
- Start date.
- End date.
- Contact information.
- Featured flag.
- Image or logo.
- Members-only visibility flag.
- Status: draft, active, expired, archived.

Recommended content fields for each business:

- Business name.
- Category.
- Logo.
- Short description.
- Full profile.
- Website.
- Phone.
- Address.
- Chamber status.
- Offer count.

## UX guidance for version 1

The product should feel simple and credible, not overloaded. The chamber’s known examples are fairly lightweight, and the best first release should emphasize clarity over feature quantity.[cite:40][cite:41]

Recommended UX principles:

- Member value should be obvious within the first screen after login.
- Deals should be browseable in under two taps.
- Each deal should state exactly how to redeem it.
- Businesses should feel trustworthy and local.
- The app should avoid making users guess whether a perk is active, expired, or members-only.

## Suggested first-release feature set

Include in v1:

- Member sign-in through existing GrowthZone flow.
- Featured deals.
- All deals list.
- Business directory for participating partners.
- Deal detail and redemption instructions.
- Profile screen with member status.
- Support/contact screen.
- Optional digital member card placeholder.

Postpone until later phases:

- Push notifications.
- Favorites and saved deals syncing across devices.
- In-app redemption tracking with QR codes.
- Business-side self-service publishing.
- Employee sub-accounts.
- Geo-aware discovery.
- Android build parity if the current focus is iOS first.

## Risk list for Cursor to account for

### Authentication risk

GrowthZone may require chamber-specific vendor setup for SSO or API access, so the login layer should be isolated and replaceable. GrowthZone’s help resources indicate SSO and API support exist, but tenant-specific access and implementation details may vary.[cite:55][cite:58][cite:59][cite:62]

### Content risk

If chamber staff do not have a simple process for updating offers, app content will become stale. The content model must support expiration dates and easy removal of inactive offers.

### UX risk

If too much of the member experience is web-only, users may not feel the app has enough standalone value. Therefore, deal browsing and business discovery should be native first, even if authentication starts with a web-based login handoff.

### Scope risk

Do not turn v1 into a complete chamber portal. Focus on member deals, business visibility, and simple proof of membership.

## Questions the chamber still needs to answer

Cursor should treat the following as open dependencies:

1. Is GrowthZone SSO enabled for this chamber tenant?[cite:55][cite:58]
2. Does the chamber have API access to member data and related objects?[cite:59][cite:62]
3. Will deals live in GrowthZone, WordPress, or another managed source?
4. Should non-members be able to preview businesses or only see a public marketing screen?
5. Does the chamber want a digital member card in the app?
6. Will redemption be manual, code-based, or eventually QR-based?
7. Who on the chamber side will maintain deal content each month?
8. Are businesses offering one-time promotions, ongoing perks, or both?

## Immediate next actions for development

1. Build the SwiftUI shell and route structure.
2. Implement a mock auth manager and mocked deals/business services.
3. Create polished native screens for deals and participating businesses.
4. Abstract authentication behind an interface so GrowthZone-specific logic can be dropped in later.
5. Add a secure login launcher using `ASWebAuthenticationSession` once the real login endpoints and callback behavior are known.
6. Prepare a configuration file for base URLs, login URLs, feature flags, and environment settings.
7. Keep all GrowthZone-specific assumptions isolated to one integration layer.

## Cursor implementation notes

The Cursor agent should optimize for clean architecture, replaceable integration layers, and fast UI prototyping. Do not hardwire GrowthZone logic throughout the codebase; wrap external behavior in services and protocols so the app can begin with mocks and later transition to real endpoints with minimal refactoring.[cite:59]

The app should also be written so an Android version can be planned later without changing the product model. Even though this document is for Swift development, the business logic, naming, data contracts, and screen flows should remain platform-agnostic where possible.

## Suggested success criteria

A successful first build should achieve the following:

- A member can launch the app and understand its purpose immediately.
- A member can enter the GrowthZone-backed login flow without confusion.
- After login, the member can browse current deals and participating businesses in a native interface.
- The app clearly distinguishes active offers, expired offers, and member-only content.
- The app can later replace mock services with real GrowthZone or WordPress-connected services without major architectural change.

## Final direction

Build the app as a native SwiftUI chamber-benefits experience on top of a hybrid membership foundation: WordPress for website content, GrowthZone for login and member identity, and a modular service layer for deals and business content. This is the most practical path for a chamber project of this size because it keeps risk low while still creating a product that feels meaningfully better than a mobile web page.[cite:55][cite:58][cite:59][cite:66]
