import AppKit
import Foundation

@MainActor
public final class ClaudePetLoadingView: NSView {
    private let startedAt = Date()
    private var timer: Timer?

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        startAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        startAnimation()
    }

    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.needsDisplay = true
            }
        }
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            timer?.invalidate()
            timer = nil
        }
    }

    public override var intrinsicContentSize: NSSize {
        NSSize(width: 300, height: 190)
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let frame = PetLoadingFrame(elapsed: Date().timeIntervalSince(startedAt))
        let bounds = self.bounds
        let centerX = bounds.midX
        let baseY = bounds.minY + 58

        drawLaptop(centerX: centerX, baseY: baseY)
        drawPet(centerX: centerX, baseY: baseY + 44, frame: frame)
        drawCodeBubbles(centerX: centerX, baseY: baseY + 108, frame: frame)
        drawStatus(frame.statusText, centerX: centerX, y: bounds.minY + 10)
    }

    private func drawPet(centerX: CGFloat, baseY: CGFloat, frame: PetLoadingFrame) {
        let bodyRect = NSRect(x: centerX - 50, y: baseY - 18, width: 100, height: 76)
        NSColor(calibratedRed: 0.93, green: 0.78, blue: 0.58, alpha: 1).setFill()
        NSBezierPath(roundedRect: bodyRect, xRadius: 28, yRadius: 28).fill()

        NSColor(calibratedRed: 0.78, green: 0.52, blue: 0.34, alpha: 1).setFill()
        let leftEar = NSBezierPath()
        leftEar.move(to: NSPoint(x: centerX - 36, y: baseY + 50))
        leftEar.line(to: NSPoint(x: centerX - 24, y: baseY + 76 + frame.earOffset))
        leftEar.line(to: NSPoint(x: centerX - 8, y: baseY + 52))
        leftEar.close()
        leftEar.fill()

        let rightEar = NSBezierPath()
        rightEar.move(to: NSPoint(x: centerX + 8, y: baseY + 52))
        rightEar.line(to: NSPoint(x: centerX + 24, y: baseY + 76 - frame.earOffset))
        rightEar.line(to: NSPoint(x: centerX + 36, y: baseY + 50))
        rightEar.close()
        rightEar.fill()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: centerX - 24, y: baseY + 20, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: centerX + 16, y: baseY + 20, width: 8, height: 10)).fill()

        NSColor(calibratedWhite: 0.18, alpha: 1).setStroke()
        let smile = NSBezierPath()
        smile.lineWidth = 2
        smile.move(to: NSPoint(x: centerX - 10, y: baseY + 8))
        smile.curve(
            to: NSPoint(x: centerX + 10, y: baseY + 8),
            controlPoint1: NSPoint(x: centerX - 4, y: baseY),
            controlPoint2: NSPoint(x: centerX + 4, y: baseY)
        )
        smile.stroke()

        drawPaw(x: centerX - 34, y: baseY - 16 + CGFloat(frame.pawOffset))
        drawPaw(x: centerX + 18, y: baseY - 16 - CGFloat(frame.pawOffset))
    }

    private func drawPaw(x: CGFloat, y: CGFloat) {
        NSColor(calibratedRed: 0.86, green: 0.62, blue: 0.42, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 28, height: 18), xRadius: 9, yRadius: 9).fill()
    }

    private func drawLaptop(centerX: CGFloat, baseY: CGFloat) {
        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: centerX - 72, y: baseY, width: 144, height: 58), xRadius: 8, yRadius: 8).fill()

        NSColor(calibratedRed: 0.42, green: 0.78, blue: 0.72, alpha: 1).setStroke()
        let lines = [
            NSRect(x: centerX - 48, y: baseY + 38, width: 42, height: 2),
            NSRect(x: centerX - 48, y: baseY + 26, width: 72, height: 2),
            NSRect(x: centerX - 48, y: baseY + 14, width: 54, height: 2)
        ]
        for line in lines {
            NSBezierPath(rect: line).stroke()
        }

        NSColor(calibratedWhite: 0.24, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: centerX - 86, y: baseY - 12, width: 172, height: 14), xRadius: 7, yRadius: 7).fill()
    }

    private func drawCodeBubbles(centerX: CGFloat, baseY: CGFloat, frame: PetLoadingFrame) {
        let active = frame.dotCount
        for index in 0..<4 {
            let alpha = index < active ? 0.95 : 0.28
            NSColor(calibratedRed: 0.72, green: 0.88, blue: 1, alpha: alpha).setFill()
            let x = centerX - 54 + CGFloat(index * 36)
            NSBezierPath(ovalIn: NSRect(x: x, y: baseY + CGFloat(index % 2) * 6, width: 12, height: 12)).fill()
        }
    }

    private func drawStatus(_ text: String, centerX: CGFloat, y: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.86, alpha: 1)
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: centerX - size.width / 2, y: y), withAttributes: attributes)
    }
}
