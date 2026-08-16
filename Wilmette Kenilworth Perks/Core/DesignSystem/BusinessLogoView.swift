import SwiftUI

enum BusinessLogoShape: Shape {
    case circle
    case roundedRect(cornerRadius: CGFloat = WKCCRadius.md)

    func path(in rect: CGRect) -> Path {
        switch self {
        case .circle:
            Circle().path(in: rect)
        case .roundedRect(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
        }
    }
}

/// Displays a business logo URL, or a WKCC-branded placeholder when missing/failed.
struct BusinessLogoView: View {
    let url: URL?
    var size: CGFloat = 56
    var shape: BusinessLogoShape = .roundedRect()

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty:
                        Color(white: 0.9)
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            WKCCColors.accent.opacity(0.15)

            Image("WKCCLogo")
                .resizable()
                .scaledToFit()
                .padding(size * 0.18)
                .accessibilityLabel(AppConfig.chamberName)
        }
    }
}
