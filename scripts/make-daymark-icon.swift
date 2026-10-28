// Run from the repository root: swift scripts/make-daymark-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let output = URL(fileURLWithPath: "apps/Daymark/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
}
let gradient = CGGradient(colorsSpace: space,
                         colors: [color(0.98, 0.58, 0.66), color(0.94, 0.36, 0.53)] as CFArray,
                         locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
context.setFillColor(color(1, 0.97, 0.97))
context.addPath(CGPath(roundedRect: CGRect(x: 212, y: 216, width: 600, height: 592),
                       cornerWidth: 135, cornerHeight: 135, transform: nil))
context.fillPath()
context.setStrokeColor(color(0.98, 0.78, 0.82))
context.setLineWidth(38)
context.strokeEllipse(in: CGRect(x: 332, y: 332, width: 360, height: 360))
context.setStrokeColor(color(0.94, 0.40, 0.56))
context.setLineWidth(48)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 406, y: 511))
context.addLine(to: CGPoint(x: 481, y: 434))
context.addLine(to: CGPoint(x: 623, y: 595))
context.strokePath()
context.setFillColor(color(0.94, 0.40, 0.56))
for x in [384, 640] {
    context.fillEllipse(in: CGRect(x: x - 21, y: 741, width: 42, height: 84))
}
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Couldn’t write icon") }
print("Wrote \(output.path)")
