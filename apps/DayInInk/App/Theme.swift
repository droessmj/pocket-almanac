import SwiftUI
import UIKit
import HabitKit

enum DayInInkTheme {
    static let background = Color(hex: 0xF4F0E7)
    static let ink = Color(hex: 0x202F43)
    static let secondary = Color(hex: 0x69717C)
    static let accent = Color(hex: 0x263E5B)
    static let paper = Color(hex: 0xFFFCF5)
    static let rule = Color(hex: 0xD8D6D0)

    /// Use the system handwriting face with Dynamic Type and a readable fallback.
    static func handwriting(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        let name = "Noteworthy-Light"
        guard UIFont(name: name, size: size) != nil else {
            return .system(style, design: .serif)
        }
        return .custom(name, size: size, relativeTo: style)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}

extension HabitColor {
    var tint: Color {
        switch self {
        case .blue: Color(hex: 0x506A88)
        case .lavender: Color(hex: 0x82748F)
        case .amber: Color(hex: 0xA0824A)
        case .mint: Color(hex: 0x6B837B)
        case .coral: Color(hex: 0xAA7762)
        case .rose: Color(hex: 0xA17480)
        }
    }

    var label: String { rawValue.capitalized }
}

func amount(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
}

struct HabitIcon: View {
    let habit: Habit
    var size: CGFloat = 46

    var body: some View {
        Text(habit.emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(habit.color.tint.opacity(0.4), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

struct ProgressRing: View {
    var fraction: Double
    var color: Color = DayInInkTheme.accent
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.14), lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

struct EmptyHabits: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 40, weight: .light)).foregroundStyle(DayInInkTheme.accent)
            Text(title).font(DayInInkTheme.handwriting(24, relativeTo: .title3))
            Text(message).font(DayInInkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DayInInkTheme.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(DayInInkTheme.accent)
            }
        }
        .frame(maxWidth: .infinity).padding(32)
    }
}

/// A quiet writing surface; decoration stays out of the accessibility tree.
struct PaperSurface: View {
    var body: some View {
        DayInInkTheme.background.overlay {
            Canvas { context, size in
                var rules = Path()
                for y in stride(from: CGFloat(28), to: size.height, by: 28) {
                    rules.move(to: CGPoint(x: 0, y: y))
                    rules.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(rules, with: .color(DayInInkTheme.ink.opacity(0.025)), lineWidth: 0.5)
            }
            .accessibilityHidden(true).allowsHitTesting(false)
        }
    }
}

extension View {
    func paperCard() -> some View {
        self.background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(DayInInkTheme.rule, lineWidth: 0.75))
    }

    func dayininkCard() -> some View {
        self.padding(20).paperCard()
    }
}
