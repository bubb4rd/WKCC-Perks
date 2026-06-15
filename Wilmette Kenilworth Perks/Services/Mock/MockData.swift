import Foundation

enum MockData {
    static let sampleMember = MemberProfile(
        id: "member-001",
        firstName: "Sarah",
        lastName: "Mitchell",
        email: "sarah.mitchell@example.com",
        membershipTier: .gold,
        membershipStatus: .active,
        companyId: "biz-003",
        companyName: "North Shore Financial Group",
        memberSince: Calendar.current.date(from: DateComponents(year: 2019, month: 3, day: 15)),
        entitlements: .fullMember
    )

    static let sampleSession = AuthSession(
        accessToken: "mock-access-token",
        refreshToken: "mock-refresh-token",
        expiresAt: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
        member: sampleMember
    )

    static let inactiveMember = MemberProfile(
        id: "member-002",
        firstName: "James",
        lastName: "Chen",
        email: "james.chen@example.com",
        membershipTier: .basic,
        membershipStatus: .expired,
        companyId: nil,
        companyName: nil,
        memberSince: nil,
        entitlements: .restricted
    )

    private static let calendar = Calendar.current

    private static func daysFromNow(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: Date())!
    }

    static let dealSummaries: [DealSummary] = [
        DealSummary(
            id: "deal-001",
            title: "20% Off Your Purchase",
            businessId: "biz-001",
            businessName: "Central Street Café",
            shortDescription: "Enjoy 20% off any dine-in or takeout order.",
            category: .dining,
            expirationDate: daysFromNow(45),
            isFeatured: true,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-002",
            title: "Free Gift with Purchase",
            businessId: "biz-002",
            businessName: "Kenilworth Books & Gifts",
            shortDescription: "Receive a complimentary gift with any purchase over $50.",
            category: .retail,
            expirationDate: daysFromNow(60),
            isFeatured: true,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-003",
            title: "Complimentary Consultation",
            businessId: "biz-003",
            businessName: "North Shore Financial Group",
            shortDescription: "Free 30-minute financial planning consultation for chamber members.",
            category: .services,
            expirationDate: daysFromNow(90),
            isFeatured: false,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-004",
            title: "Members-Only Networking Breakfast",
            businessId: "biz-004",
            businessName: "Wilmette Community Center",
            shortDescription: "Complimentary admission to the monthly chamber networking breakfast.",
            category: .events,
            expirationDate: daysFromNow(12),
            isFeatured: true,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-005",
            title: "15% Off First Visit",
            businessId: "biz-005",
            businessName: "Lakeview Wellness Studio",
            shortDescription: "New members save 15% on yoga classes, massage, and wellness services.",
            category: .healthWellness,
            expirationDate: daysFromNow(30),
            isFeatured: false,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-006",
            title: "Buy One, Get One Free Pastry",
            businessId: "biz-001",
            businessName: "Central Street Café",
            shortDescription: "BOGO on any pastry with purchase of a beverage.",
            category: .dining,
            expirationDate: daysFromNow(8),
            isFeatured: false,
            membersOnly: true
        ),
        DealSummary(
            id: "deal-007",
            title: "10% Off Home Services",
            businessId: "biz-006",
            businessName: "GreenLeaf Landscaping",
            shortDescription: "Chamber members receive 10% off seasonal lawn care packages.",
            category: .services,
            expirationDate: daysFromNow(120),
            isFeatured: false,
            membersOnly: true
        )
    ]

    static let dealDetails: [DealDetail] = [
        DealDetail(
            id: "deal-001",
            title: "20% Off Your Purchase",
            businessId: "biz-001",
            businessName: "Central Street Café",
            description: "Central Street Café is proud to support WKCC members with 20% off any dine-in or takeout order. Enjoy locally sourced ingredients and a welcoming neighborhood atmosphere.",
            terms: "Valid for one use per visit. Cannot be combined with other offers. Excludes alcohol. Not valid on holidays.",
            redemptionInstructions: "Show this screen to your server before ordering. Mention you are a WKCC member.",
            redemptionCode: nil,
            startDate: daysFromNow(-30),
            expirationDate: daysFromNow(45),
            category: .dining,
            imageURL: nil,
            membersOnly: true,
            isFeatured: true
        ),
        DealDetail(
            id: "deal-002",
            title: "Free Gift with Purchase",
            businessId: "biz-002",
            businessName: "Kenilworth Books & Gifts",
            description: "Browse our curated selection of books, gifts, and local artisan goods. Chamber members receive a complimentary gift with any purchase of $50 or more.",
            terms: "One gift per member per visit. Gift selection varies by availability.",
            redemptionInstructions: "Present your member card at checkout. Minimum purchase of $50 required before tax.",
            redemptionCode: "WKCC-GIFT",
            startDate: daysFromNow(-14),
            expirationDate: daysFromNow(60),
            category: .retail,
            imageURL: nil,
            membersOnly: true,
            isFeatured: true
        ),
        DealDetail(
            id: "deal-003",
            title: "Complimentary Consultation",
            businessId: "biz-003",
            businessName: "North Shore Financial Group",
            description: "Schedule a complimentary 30-minute financial planning session with one of our certified advisors. Perfect for retirement planning, investment review, or business financial strategy.",
            terms: "New clients only. Appointment required. One consultation per member household.",
            redemptionInstructions: "Call to schedule and mention your WKCC membership. Use code WKCC-CONSULT when booking online.",
            redemptionCode: "WKCC-CONSULT",
            startDate: daysFromNow(-60),
            expirationDate: daysFromNow(90),
            category: .services,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        ),
        DealDetail(
            id: "deal-004",
            title: "Members-Only Networking Breakfast",
            businessId: "biz-004",
            businessName: "Wilmette Community Center",
            description: "Join fellow chamber members for our monthly networking breakfast. Connect with local business leaders over coffee and a light breakfast.",
            terms: "Registration required. Space is limited. One complimentary admission per member.",
            redemptionInstructions: "Show this screen at the registration desk on the morning of the event.",
            redemptionCode: nil,
            startDate: daysFromNow(-7),
            expirationDate: daysFromNow(12),
            category: .events,
            imageURL: nil,
            membersOnly: true,
            isFeatured: true
        ),
        DealDetail(
            id: "deal-005",
            title: "15% Off First Visit",
            businessId: "biz-005",
            businessName: "Lakeview Wellness Studio",
            description: "Discover yoga, pilates, massage therapy, and wellness coaching at Lakeview Wellness Studio. First-time chamber member visitors save 15% on any service.",
            terms: "First visit only. Cannot be combined with introductory packages.",
            redemptionInstructions: "Mention WKCC membership when booking or checking in for your first appointment.",
            redemptionCode: nil,
            startDate: daysFromNow(-20),
            expirationDate: daysFromNow(30),
            category: .healthWellness,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        ),
        DealDetail(
            id: "deal-006",
            title: "Buy One, Get One Free Pastry",
            businessId: "biz-001",
            businessName: "Central Street Café",
            description: "Start your morning right with our freshly baked pastries. Buy any pastry and get a second one free with the purchase of a beverage.",
            terms: "Equal or lesser value pastry is free. One per member per day.",
            redemptionInstructions: "Show this deal at the counter when ordering.",
            redemptionCode: nil,
            startDate: daysFromNow(-5),
            expirationDate: daysFromNow(8),
            category: .dining,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        ),
        DealDetail(
            id: "deal-007",
            title: "10% Off Home Services",
            businessId: "biz-006",
            businessName: "GreenLeaf Landscaping",
            description: "GreenLeaf Landscaping offers professional lawn care, garden design, and seasonal maintenance for North Shore homes. Chamber members save 10% on any seasonal package.",
            terms: "Applies to new seasonal contracts only. Minimum 3-month commitment.",
            redemptionInstructions: "Request a quote and mention your WKCC membership to receive the discount.",
            redemptionCode: "WKCC-LAWN10",
            startDate: daysFromNow(-10),
            expirationDate: daysFromNow(120),
            category: .services,
            imageURL: nil,
            membersOnly: true,
            isFeatured: false
        )
    ]

    static let businesses: [ChamberBusiness] = [
        ChamberBusiness(
            id: "biz-001",
            name: "Central Street Café",
            category: .dining,
            shortDescription: "Neighborhood café serving breakfast, lunch, and locally roasted coffee.",
            fullDescription: "A Wilmette favorite since 2008, Central Street Café features seasonal menus, house-made pastries, and a patio perfect for warm-weather dining.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/central-street-cafe"),
            phone: "(847) 256-1234",
            address: "1200 Central St, Wilmette, IL 60091",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-001" },
            redemptionNotes: "Please show your member perk before ordering."
        ),
        ChamberBusiness(
            id: "biz-002",
            name: "Kenilworth Books & Gifts",
            category: .retail,
            shortDescription: "Independent bookstore and gift shop in the heart of Kenilworth.",
            fullDescription: "Kenilworth Books & Gifts carries bestsellers, children's books, greeting cards, and gifts from local artisans.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/kenilworth-books"),
            phone: "(847) 251-5678",
            address: "545 Sheridan Rd, Kenilworth, IL 60043",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-002" },
            redemptionNotes: nil
        ),
        ChamberBusiness(
            id: "biz-003",
            name: "North Shore Financial Group",
            category: .services,
            shortDescription: "Financial planning and wealth management for individuals and businesses.",
            fullDescription: "North Shore Financial Group provides comprehensive financial planning, investment management, and retirement strategies tailored to North Shore families and businesses.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/north-shore-financial"),
            phone: "(847) 256-9012",
            address: "800 Green Bay Rd, Wilmette, IL 60091",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-003" },
            redemptionNotes: "Appointments required for all consultations."
        ),
        ChamberBusiness(
            id: "biz-004",
            name: "Wilmette Community Center",
            category: .events,
            shortDescription: "Community hub hosting chamber events and local gatherings.",
            fullDescription: "The Wilmette Community Center hosts chamber networking events, workshops, and community programs throughout the year.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/wilmette-community"),
            phone: "(847) 256-3456",
            address: "615 Ridge Rd, Wilmette, IL 60091",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-004" },
            redemptionNotes: nil
        ),
        ChamberBusiness(
            id: "biz-005",
            name: "Lakeview Wellness Studio",
            category: .healthWellness,
            shortDescription: "Yoga, pilates, massage, and holistic wellness services.",
            fullDescription: "Lakeview Wellness Studio offers group fitness classes, private training, massage therapy, and nutrition coaching in a serene lakefront setting.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/lakeview-wellness"),
            phone: "(847) 251-7890",
            address: "2100 Lake Ave, Wilmette, IL 60091",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-005" },
            redemptionNotes: nil
        ),
        ChamberBusiness(
            id: "biz-006",
            name: "GreenLeaf Landscaping",
            category: .services,
            shortDescription: "Professional landscaping and lawn care for North Shore homes.",
            fullDescription: "GreenLeaf Landscaping provides design, installation, and maintenance services with an emphasis on sustainable practices and native plantings.",
            logoURL: nil,
            websiteURL: URL(string: "https://example.com/greenleaf"),
            phone: "(847) 256-4567",
            address: "450 Skokie Blvd, Wilmette, IL 60091",
            isChamberPartner: true,
            activeDeals: dealSummaries.filter { $0.businessId == "biz-006" },
            redemptionNotes: "Discount applies to new seasonal contracts."
        )
    ]
}
