import SwiftUI
import HabitKit

enum DaymarkTheme {
    static let background = Color(hex: 0xF6F7FA)
    static let ink = Color(hex: 0x252831)
    static let secondary = Color(hex: 0x7C808D)
    static let accent = Color(hex: 0xF47190)
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
        case .blue: Color(hex: 0x3C96E9)
        case .lavender: Color(hex: 0xB96ADE)
        case .amber: Color(hex: 0xD7A245)
        case .mint: Color(hex: 0x47AB91)
        case .coral: Color(hex: 0xED8B70)
        case .rose: Color(hex: 0xED779E)
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
            .background(habit.color.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct ProgressRing: View {
    var fraction: Double
    var color: Color = DaymarkTheme.accent
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
            Text("🌱").font(.system(size: 48))
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(DaymarkTheme.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).tint(DaymarkTheme.accent)
            }
        }
        .frame(maxWidth: .infinity).padding(32)
    }
}

extension View {
    func daymarkCard() -> some View {
        self.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}
