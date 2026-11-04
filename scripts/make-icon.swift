// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

// Renders the Blotter app icon (1024×1024, opaque) into the asset catalog.
// Run from the repo root: swift scripts/make-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = URL(fileURLWithPath: "apps/Blotter/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Background: indigo (top) to teal (bottom). CG's origin is bottom-left.
let gradient = CGGradient(colorsSpace: space, colors: [rgb(0x0EA5A4), rgb(0x4F46E5)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])

// Message bubble with a tail at the lower left.
ctx.setFillColor(rgb(0xFFFFFF))
ctx.addPath(CGPath(roundedRect: CGRect(x: 172, y: 290, width: 680, height: 540), cornerWidth: 150, cornerHeight: 150,
                   transform: nil))
ctx.fillPath()
ctx.move(to: CGPoint(x: 290, y: 330))
ctx.addLine(to: CGPoint(x: 440, y: 300))
ctx.addLine(to: CGPoint(x: 230, y: 190))
ctx.closePath()
ctx.fillPath()

// Incoming messages: three dots above the funnel, the outer two faded (filtered out).
for (x, alpha) in [(412.0, 0.35), (512.0, 1.0), (612.0, 0.35)] {
    ctx.setFillColor(rgb(0x4338CA).copy(alpha: alpha)!)
    ctx.fillEllipse(in: CGRect(x: x - 26, y: 712, width: 52, height: 52))
}

// Funnel: wide mouth tapering to a spout.
ctx.setFillColor(rgb(0x4338CA))
ctx.move(to: CGPoint(x: 332, y: 672))
ctx.addLine(to: CGPoint(x: 692, y: 672))
ctx.addLine(to: CGPoint(x: 552, y: 512))
ctx.addLine(to: CGPoint(x: 552, y: 400))
ctx.addLine(to: CGPoint(x: 472, y: 400))
ctx.addLine(to: CGPoint(x: 472, y: 512))
ctx.closePath()
ctx.fillPath()

try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("failed to write \(out.path)") }
print("wrote \(out.path)")
