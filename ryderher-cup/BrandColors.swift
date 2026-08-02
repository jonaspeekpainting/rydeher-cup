import SwiftUI

enum BrandColors {
  /// Logo background — deep muted indigo `#3F3651`.
  static let primary = Color("BrandPrimary")
  /// Slightly lighter indigo for fills / cards on brand surfaces.
  static let primarySoft = Color("BrandPrimarySoft")
  static let splashBackground = Color("BrandSplashBackground")
  static let onPrimary = Color.white

  /// Soft page wash derived from the logo indigo (not flat system gray).
  static let canvas = Color(red: 0.96, green: 0.95, blue: 0.97)
  static let card = Color.white
  static let hairline = Color(red: 0.247, green: 0.212, blue: 0.318).opacity(0.14)
  static let ink = Color(red: 0.18, green: 0.15, blue: 0.24)
  static let inkMuted = Color(red: 0.247, green: 0.212, blue: 0.318).opacity(0.62)

  static let liveGradient = LinearGradient(
    colors: [
      Color(red: 0.28, green: 0.24, blue: 0.36),
      Color(red: 0.18, green: 0.14, blue: 0.26),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Hookers lean cooler / deeper on the logo indigo.
  static let hookers = Color(red: 0.22, green: 0.18, blue: 0.30)
  /// Slicers lean warmer / softer purple from the same family.
  static let slicers = Color(red: 0.42, green: 0.30, blue: 0.46)

  static func team(_ slug: String?) -> Color {
    switch slug {
    case "hookers": return hookers
    case "slicers": return slicers
    default: return primary
    }
  }
}

// MARK: - Shared brand chrome

struct BrandScreenBackground: View {
  var body: some View {
    BrandColors.canvas
      .ignoresSafeArea()
      .overlay(alignment: .top) {
        LinearGradient(
          colors: [
            BrandColors.primary.opacity(0.10),
            BrandColors.primary.opacity(0),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 220)
        .ignoresSafeArea(edges: .top)
      }
  }
}

struct BrandSectionHeader: View {
  let title: String
  var subtitle: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.system(.title3, design: .serif).weight(.semibold))
        .foregroundStyle(BrandColors.ink)
      if let subtitle {
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(BrandColors.inkMuted)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct BrandCard<Content: View>: View {
  var padding: CGFloat = 16
  @ViewBuilder var content: () -> Content

  var body: some View {
    content()
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(BrandColors.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(BrandColors.hairline, lineWidth: 1)
      )
      .shadow(color: BrandColors.primary.opacity(0.06), radius: 10, y: 4)
  }
}

struct CupScoreHero: View {
  let hookersPoints: Double
  let slicersPoints: Double
  var title: String = "Ryde-Her Cup"
  var subtitle: String? = nil

  private var leader: String? {
    if hookersPoints > slicersPoints { return "Hookers lead" }
    if slicersPoints > hookersPoints { return "Slicers lead" }
    return "All square"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(.title2, design: .serif).weight(.semibold))
            .foregroundStyle(BrandColors.onPrimary)
          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(BrandColors.onPrimary.opacity(0.72))
          }
        }
        Spacer()
        if let leader {
          Text(leader)
            .font(.caption.weight(.semibold))
            .foregroundStyle(BrandColors.onPrimary.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(BrandColors.onPrimary.opacity(0.14))
            .clipShape(Capsule())
        }
      }

      Rectangle()
        .fill(BrandColors.onPrimary.opacity(0.22))
        .frame(height: 1)

      HStack(alignment: .center, spacing: 0) {
        teamColumn(
          name: "Hookers",
          points: hookersPoints,
          alignment: .leading,
          accent: BrandColors.hookers
        )

        Text("VS")
          .font(.caption.weight(.bold))
          .foregroundStyle(BrandColors.onPrimary.opacity(0.45))
          .frame(width: 36)

        teamColumn(
          name: "Slicers",
          points: slicersPoints,
          alignment: .trailing,
          accent: BrandColors.slicers
        )
      }
    }
    .padding(18)
    .background(BrandColors.liveGradient)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .shadow(color: BrandColors.primary.opacity(0.35), radius: 16, y: 8)
  }

  private func teamColumn(
    name: String,
    points: Double,
    alignment: HorizontalAlignment,
    accent _: Color
  ) -> some View {
    VStack(alignment: alignment, spacing: 6) {
      HStack(spacing: 6) {
        if alignment == .trailing { Spacer(minLength: 0) }
        Text(name.uppercased())
          .font(.caption2.weight(.bold))
          .tracking(0.6)
          .foregroundStyle(BrandColors.onPrimary.opacity(0.72))
        if alignment == .leading { Spacer(minLength: 0) }
      }
      Text(pointsText(points))
        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(BrandColors.onPrimary)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
  }

  private func pointsText(_ value: Double) -> String {
    value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
  }
}

struct BrandLogoMark: View {
  var maxWidth: CGFloat = 220
  var showsWordmark: Bool = false

  var body: some View {
    VStack(spacing: 10) {
      Image("BrandLogo")
        .resizable()
        .scaledToFit()
        .frame(maxWidth: maxWidth)
        .accessibilityLabel("Ryde-Her Cup")

      if showsWordmark {
        Text("Ryde-Her Cup ’26")
          .font(.system(.title3, design: .serif).weight(.semibold))
          .foregroundStyle(BrandColors.onPrimary)
      }
    }
  }
}

struct BrandPrimaryButtonStyle: ButtonStyle {
  var isEnabled: Bool = true

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(BrandColors.onPrimary.opacity(isEnabled ? 1 : 0.55))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(
        BrandColors.primarySoft.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

struct BrandSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(BrandColors.onPrimary.opacity(configuration.isPressed ? 0.7 : 1))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(BrandColors.onPrimary.opacity(0.55), lineWidth: 1.5)
          .background(
            BrandColors.onPrimary.opacity(configuration.isPressed ? 0.12 : 0)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          )
      )
  }
}
