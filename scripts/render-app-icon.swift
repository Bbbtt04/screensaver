#!/usr/bin/env swift

import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "assets/AppIcon.iconset")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let canvasSize = NSSize(width: 1024, height: 1024)

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func path(_ points: [NSPoint]) -> NSBezierPath {
    let bezier = NSBezierPath()
    guard let first = points.first else { return bezier }
    bezier.move(to: first)
    for point in points.dropFirst() {
        bezier.line(to: point)
    }
    bezier.close()
    return bezier
}

func drawIcon(in rect: NSRect) {
    NSGraphicsContext.current?.imageInterpolation = .high

    NSColor.black.setFill()
    rect.fill()

    let outer = roundedRect(NSRect(x: 42, y: 42, width: 940, height: 940), radius: 210)
    NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.08, alpha: 1).setFill()
    outer.fill()

    NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.26, alpha: 1).setStroke()
    outer.lineWidth = 8
    outer.stroke()

    let monitor = roundedRect(NSRect(x: 174, y: 260, width: 510, height: 510), radius: 52)
    NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.18, alpha: 1).setFill()
    monitor.fill()
    NSColor(calibratedRed: 0.62, green: 0.68, blue: 0.76, alpha: 1).setStroke()
    monitor.lineWidth = 10
    monitor.stroke()

    let screen = roundedRect(NSRect(x: 200, y: 292, width: 456, height: 448), radius: 34)
    NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.07, alpha: 1).setFill()
    screen.fill()

    NSColor(calibratedRed: 0.10, green: 0.56, blue: 1.0, alpha: 0.92).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: 250, y: 355, width: 300, height: 300))
    ring.lineWidth = 11
    ring.stroke()
    NSColor(calibratedRed: 0.10, green: 0.48, blue: 1.0, alpha: 0.32).setStroke()
    let outerRing = NSBezierPath(ovalIn: NSRect(x: 220, y: 325, width: 360, height: 360))
    outerRing.lineWidth = 4
    outerRing.stroke()

    NSColor.white.setFill()
    let star = path([
        NSPoint(x: 410, y: 508),
        NSPoint(x: 446, y: 522),
        NSPoint(x: 410, y: 536),
        NSPoint(x: 396, y: 572),
        NSPoint(x: 382, y: 536),
        NSPoint(x: 346, y: 522),
        NSPoint(x: 382, y: 508),
        NSPoint(x: 396, y: 472)
    ])
    star.fill()

    NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.23, alpha: 1).setFill()
    roundedRect(NSRect(x: 350, y: 202, width: 320, height: 34), radius: 17).fill()
    roundedRect(NSRect(x: 430, y: 234, width: 160, height: 46), radius: 18).fill()

    let curtain = NSBezierPath()
    curtain.move(to: NSPoint(x: 410, y: 780))
    curtain.curve(
        to: NSPoint(x: 862, y: 300),
        controlPoint1: NSPoint(x: 686, y: 790),
        controlPoint2: NSPoint(x: 720, y: 570)
    )
    curtain.curve(
        to: NSPoint(x: 930, y: 245),
        controlPoint1: NSPoint(x: 892, y: 250),
        controlPoint2: NSPoint(x: 916, y: 245)
    )
    curtain.curve(
        to: NSPoint(x: 826, y: 210),
        controlPoint1: NSPoint(x: 900, y: 185),
        controlPoint2: NSPoint(x: 858, y: 198)
    )
    curtain.curve(
        to: NSPoint(x: 380, y: 780),
        controlPoint1: NSPoint(x: 670, y: 270),
        controlPoint2: NSPoint(x: 530, y: 560)
    )
    curtain.close()
    NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.05, alpha: 1).setFill()
    curtain.fill()
    NSColor(calibratedRed: 0.55, green: 0.61, blue: 0.70, alpha: 0.7).setStroke()
    curtain.lineWidth = 5
    curtain.stroke()

    NSColor(calibratedRed: 0.22, green: 0.27, blue: 0.34, alpha: 0.85).setStroke()
    for offset in stride(from: 0, through: 180, by: 45) {
        let fold = NSBezierPath()
        fold.move(to: NSPoint(x: 470 + CGFloat(offset), y: 735 - CGFloat(offset) * 0.35))
        fold.curve(
            to: NSPoint(x: 850, y: 250),
            controlPoint1: NSPoint(x: 560 + CGFloat(offset) * 0.35, y: 590),
            controlPoint2: NSPoint(x: 715 + CGFloat(offset) * 0.20, y: 385)
        )
        fold.lineWidth = 3
        fold.stroke()
    }

    let shield = NSBezierPath()
    shield.move(to: NSPoint(x: 512, y: 422))
    shield.line(to: NSPoint(x: 660, y: 360))
    shield.line(to: NSPoint(x: 660, y: 168))
    shield.curve(
        to: NSPoint(x: 512, y: 80),
        controlPoint1: NSPoint(x: 650, y: 122),
        controlPoint2: NSPoint(x: 588, y: 92)
    )
    shield.curve(
        to: NSPoint(x: 364, y: 168),
        controlPoint1: NSPoint(x: 436, y: 92),
        controlPoint2: NSPoint(x: 374, y: 122)
    )
    shield.line(to: NSPoint(x: 364, y: 360))
    shield.close()
    NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.16, alpha: 1).setFill()
    shield.fill()
    NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.88, alpha: 1).setStroke()
    shield.lineWidth = 10
    shield.stroke()
    NSColor(calibratedRed: 0.0, green: 0.55, blue: 1.0, alpha: 0.90).setStroke()
    shield.lineWidth = 5
    shield.stroke()

    NSColor(calibratedRed: 0.82, green: 0.90, blue: 1.0, alpha: 1).setStroke()
    let shackle = NSBezierPath()
    shackle.lineWidth = 18
    shackle.move(to: NSPoint(x: 464, y: 268))
    shackle.curve(
        to: NSPoint(x: 560, y: 268),
        controlPoint1: NSPoint(x: 464, y: 344),
        controlPoint2: NSPoint(x: 560, y: 344)
    )
    shackle.stroke()

    NSColor(calibratedRed: 0.80, green: 0.88, blue: 0.98, alpha: 1).setFill()
    roundedRect(NSRect(x: 446, y: 184, width: 132, height: 98), radius: 18).fill()
    NSColor(calibratedRed: 0.0, green: 0.54, blue: 1.0, alpha: 0.9).setStroke()
    roundedRect(NSRect(x: 446, y: 184, width: 132, height: 98), radius: 18).stroke()

    NSColor.black.setFill()
    NSBezierPath(ovalIn: NSRect(x: 496, y: 224, width: 34, height: 34)).fill()
    path([
        NSPoint(x: 506, y: 226),
        NSPoint(x: 520, y: 226),
        NSPoint(x: 526, y: 196),
        NSPoint(x: 500, y: 196)
    ]).fill()
}

let sourceImage = NSImage(size: canvasSize)
sourceImage.lockFocus()
drawIcon(in: NSRect(origin: .zero, size: canvasSize))
sourceImage.unlockFocus()

let outputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in outputs {
    let resized = NSImage(size: NSSize(width: size, height: size))
    resized.lockFocus()
    sourceImage.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconRender", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(filename)"])
    }
    try png.write(to: outputDirectory.appendingPathComponent(filename))
}
