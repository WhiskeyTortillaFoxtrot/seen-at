import SwiftUI

struct StadiumBackdrop: View {
    var venue: String?
    var usesDailyImage = false

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.09, blue: 0.14), Color(red: 0.01, green: 0.03, blue: 0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    .black.opacity(colorSchemeContrast == .increased ? 0.58 : 0.5),
                    .black.opacity(colorSchemeContrast == .increased ? 0.82 : 0.76),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .accessibilityHidden(true)
    }

    private var image: Image? {
        if let venue, let venueImage = VenueImageService.image(for: venue) {
            return venueImage
        }
        return usesDailyImage ? VenueImageService.dailyImage() : nil
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func liquidGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(LiquidGlassModifier(shape: shape, interactive: interactive))
    }

    func groupedGlassCard() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if colorSchemeContrast == .increased {
                if interactive {
                    content.glassEffect(.regular.interactive(), in: shape)
                } else {
                    content.glassEffect(.regular, in: shape)
                }
            } else if interactive {
                content.glassEffect(.clear.interactive(), in: shape)
            } else {
                content.glassEffect(.clear, in: shape)
            }
        } else {
            if colorSchemeContrast == .increased {
                content
                    .background(.regularMaterial, in: shape)
                    .overlay { shape.stroke(.white.opacity(0.3), lineWidth: 1) }
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
                    .overlay { shape.stroke(.white.opacity(0.2), lineWidth: 1) }
            }
        }
    }
}

struct GlassListRowBackground: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(colorSchemeContrast == .increased ? .regular : .clear, in: Rectangle())
        } else {
            Rectangle()
                .fill(colorSchemeContrast == .increased ? .regularMaterial : .ultraThinMaterial)
        }
    }
}
