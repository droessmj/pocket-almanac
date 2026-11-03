// Run from the repository root: swift scripts/make-dayinink-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = URL(fileURLWithPath: "apps/DayInInk/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

// Full-bleed ivory paper. iOS supplies the icon's outer rounded mask.
context.setFillColor(color(0xF4F0E7))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setFillColor(color(0xFFFCF5))
context.fill(CGRect(x: 126, y: 0, width: 898, height: 1024))

// Notebook rules and a single binding margin, quiet enough to keep the mark legible.
context.setStrokeColor(color(0x263E5B, alpha: 0.13))
context.setLineWidth(3)
for y in stride(from: 246, through: 806, by: 112) {
    context.move(to: CGPoint(x: 126, y: y))
    context.addLine(to: CGPoint(x: 1024, y: y))
}
context.strokePath()
context.setStrokeColor(color(0x263E5B, alpha: 0.22))
context.setLineWidth(4)
context.move(to: CGPoint(x: 222, y: 0))
context.addLine(to: CGPoint(x: 222, y: 1024))
context.strokePath()

// An open checkbox and an expressive pen stroke: the day's mark on paper.
context.setStrokeColor(color(0x263E5B, alpha: 0.75))
context.setLineWidth(17)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 655, y: 690))
context.addCurve(to: CGPoint(x: 346, y: 677), control1: CGPoint(x: 550, y: 697), control2: CGPoint(x: 425, y: 691))
context.addLine(to: CGPoint(x: 335, y: 354))
context.addCurve(to: CGPoint(x: 673, y: 350), control1: CGPoint(x: 447, y: 344), control2: CGPoint(x: 574, y: 345))
context.addLine(to: CGPoint(x: 681, y: 500))
context.strokePath()

context.setStrokeColor(color(0x202F43))
context.setLineWidth(43)
context.move(to: CGPoint(x: 411, y: 526))
context.addCurve(to: CGPoint(x: 491, y: 435), control1: CGPoint(x: 437, y: 502), control2: CGPoint(x: 466, y: 458))
context.addCurve(to: CGPoint(x: 771, y: 740), control1: CGPoint(x: 565, y: 555), control2: CGPoint(x: 684, y: 701))
context.strokePath()
// Taper the end like a lifted nib.
context.setLineWidth(22)
context.move(to: CGPoint(x: 761, y: 732))
context.addQuadCurve(to: CGPoint(x: 799, y: 755), control: CGPoint(x: 782, y: 747))
context.strokePath()

try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Couldn’t write icon") }
print("Wrote \(output.path)")
