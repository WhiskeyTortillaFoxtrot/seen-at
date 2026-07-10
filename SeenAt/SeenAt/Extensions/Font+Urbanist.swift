import SwiftUI

extension Font {
    static func urbanist(_ textStyle: TextStyle, weight: Weight = .regular) -> Font {
        .custom(fontName(for: weight), size: pointSize(for: textStyle), relativeTo: textStyle)
    }

    static func urbanist(size: CGFloat, weight: Weight = .regular) -> Font {
        .custom(fontName(for: weight), size: size)
    }

    private static func fontName(for weight: Weight) -> String {
        switch weight {
        case .medium: "Urbanist-Medium"
        case .semibold: "Urbanist-SemiBold"
        case .bold, .heavy, .black: "Urbanist-Bold"
        default: "Urbanist-Regular"
        }
    }

    private static func pointSize(for textStyle: TextStyle) -> CGFloat {
        switch textStyle {
        case .caption2: 11
        case .caption: 12
        case .footnote: 13
        case .subheadline: 15
        case .callout: 16
        case .body, .headline: 17
        case .title3: 20
        case .title2: 22
        case .title: 28
        case .largeTitle: 34
        default: 17
        }
    }
}
