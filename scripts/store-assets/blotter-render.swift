import AppKit
import Foundation

// Run from repository root: swift scripts/store-assets/blotter-render.swift
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let out = root.appendingPathComponent("build/store-assets/blotter/creative")
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let iconURL = root.appendingPathComponent("apps/Blotter/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
guard let icon = NSImage(contentsOf: iconURL) else { fatalError("Missing real Blotter icon") }
let indigo = NSColor(calibratedRed: 0.20, green: 0.19, blue: 0.48, alpha: 1)
let teal = NSColor(calibratedRed: 0.32, green: 0.88, blue: 0.78, alpha: 1)
func text(_ string: String, _ rect: CGRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    (string as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style])
}
func render(_ filename: String, width: Int, height: Int, safe: CGRect) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let canvas = CGRect(x: 0, y: 0, width: width, height: height)
    indigo.setFill(); canvas.fill()
    let gradient = NSGradient(starting: NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.35, alpha: 1), ending: indigo)!
    gradient.draw(in: NSBezierPath(rect: canvas), angle: 25)
    // Quiet edge decoration intentionally stays outside the content safe rectangle.
    NSColor(calibratedRed: 0.23, green: 0.44, blue: 0.49, alpha: 1).setStroke()
    for offset in stride(from: 0, to: 900, by: 160) {
        let circle = NSBezierPath(ovalIn: CGRect(x: -650 + offset, y: -850 + offset / 2, width: 1500, height: 1500))
        circle.lineWidth = 3; circle.stroke()
    }
    let iconSize: CGFloat = filename.contains("header") ? 250 : 330
    let x = safe.minX + 48
    let center = safe.midY
    icon.draw(in: CGRect(x: x, y: center - iconSize / 2, width: iconSize, height: iconSize))
    let tx = x + iconSize + 70
    let tw = safe.maxX - tx - 40
    text("Blotter", CGRect(x: tx, y: center + 22, width: tw, height: 145), size: filename.contains("header") ? 108 : 140, weight: .bold, color: .white)
    text("SMS keyword filtering.\nYour matching rules.", CGRect(x: tx, y: center - 150, width: tw, height: 160), size: filename.contains("header") ? 49 : 63, weight: .medium, color: teal)
    NSGraphicsContext.restoreGraphicsState()
    let png = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: out.appendingPathComponent(filename))
}
// Safe rectangles are symmetric vertically; AppKit uses bottom-left coordinates.
try render("header.png", width: 3840, height: 1646, safe: CGRect(x: 1097, y: 493, width: 1646, height: 661))
try render("search-results.png", width: 3840, height: 2560, safe: CGRect(x: 836, y: 765, width: 2168, height: 1030))
print(out.path)
