import SwiftUI
import UIKit
import HabitKit

enum DayInInkTheme {
    static let background = Color(hex: 0xF4F0E7)
    static let ink = Color(hex: 0x202F43)
    static let secondary = Color(hex: 0x59616D)
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

    /// Text colors are deliberately darker than the decorative pastel rails.
    var textColor: Color {
        switch self {
        case .blue: Color(hex: 0x3C526C)
        case .lavender: Color(hex: 0x64536F)
        case .amber: Color(hex: 0x745A29)
        case .mint: Color(hex: 0x466158)
        case .coral: Color(hex: 0x80513F)
        case .rose: Color(hex: 0x79505C)
        }
    }

    var label: String { rawValue.capitalized }
}

func amount(_ value: Decimal) -> String {
    if usesScientificAmount(value) {
        return value.formatted(.number.notation(.scientific).precision(.significantDigits(1...6)))
    }
    return value.formatted(.number.precision(.fractionLength(0...8)))
}

func spokenAmount(_ value: Decimal) -> String {
    guard usesScientificAmount(value),
          let identity = decimalIdentity(NSDecimalNumber(decimal: value).stringValue) else { return amount(value) }
    let parts = identity.split(separator: "e")
    let digits = String(parts[0]).replacingOccurrences(of: "-", with: "")
    guard parts.count == 2, let power = Int(parts[1]),
          let coefficient = Decimal(string: "\(parts[0])e-\(digits.count - 1)", locale: Locale(identifier: "en_US_POSIX")) else { return amount(value) }
    return "\(coefficient.formatted(.number.precision(.significantDigits(1...6)))) times ten to the power of \(power + digits.count - 1)"
}

private func usesScientificAmount(_ value: Decimal) -> Bool {
    value != 0 && (abs(value) < Decimal(string: "0.000001")! || abs(value) >= 1_000_000_000)
}

/// Whole-input parsing: localized decimal separator and Unicode decimal digits,
/// with no grouping separators or trailing text. Exponents support exact editing.
func parseAmount(_ text: String, locale: Locale = .current) -> Decimal? {
    let separator = locale.decimalSeparator ?? "."
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    var normalized = ""
    for scalar in trimmed.unicodeScalars {
        if scalar.properties.numericType == .decimal,
           let digit = Character(String(scalar)).wholeNumberValue {
            normalized.append(String(digit))
        } else {
            normalized.unicodeScalars.append(scalar)
        }
    }
    if separator != "." && normalized.contains(".") { return nil }
    normalized = normalized.replacingOccurrences(of: separator, with: ".")
    guard normalized.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"#,
                           options: .regularExpression) != nil,
          let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
          !value.isNaN,
          decimalIdentity(normalized) == decimalIdentity(NSDecimalNumber(decimal: value).stringValue) else { return nil }
    return value
}

/// Compare the exact coefficient and exponent to reject silently rounded input.
private func decimalIdentity(_ text: String) -> String? {
    var text = text.lowercased()
    let negative = text.hasPrefix("-")
    if text.hasPrefix("-") || text.hasPrefix("+") { text.removeFirst() }
    let parts = text.split(separator: "e", omittingEmptySubsequences: false)
    guard parts.count <= 2 else { return nil }
    let parsedExponent: Int? = parts.count == 2 ? Int(parts[1]) : 0
    guard let exponent = parsedExponent, (-1000...1000).contains(exponent) else { return nil }
    let coefficient = String(parts[0])
    let fractionCount = coefficient.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
    var digits = coefficient.replacingOccurrences(of: ".", with: "")
    while digits.first == "0" { digits.removeFirst() }
    if digits.isEmpty { return "0" }
    var power = exponent - fractionCount
    while digits.last == "0" { digits.removeLast(); power += 1 }
    return "\(negative ? "-" : "")\(digits)e\(power)"
}

func editableAmount(_ value: Decimal, locale: Locale = .current) -> String {
    NSDecimalNumber(decimal: value).stringValue
        .replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
}

/// Keep date controls Gregorian like persisted day identities, while honoring timezone changes.
func habitCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .current
    calendar.locale = .current
    return calendar
}

func habitDateLabel(_ date: Date, format: Date.FormatStyle) -> String {
    var format = format
    format.calendar = habitCalendar()
    format.timeZone = .current
    return date.formatted(format)
}

extension View {
    func mutationError(_ message: Binding<String?>) -> some View {
        alert("Couldn’t save changes", isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) { Button("OK") { message.wrappedValue = nil } }
        message: { Text(message.wrappedValue ?? "Please try again.") }
    }
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
