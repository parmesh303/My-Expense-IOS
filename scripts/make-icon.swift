// Generates the 1024×1024 app icon: deep-teal gradient, a white wallet card and a ₹ mark.
// Usage: swift scripts/make-icon.swift MyExpenseApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

guard let context = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue // App Store icons must be opaque.
) else { fatalError("Could not create context") }

let ns = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = ns

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// Background: full-bleed diagonal gradient (iOS applies the rounded mask itself).
NSGradient(colors: [color(36, 168, 140), color(18, 110, 96), color(9, 62, 58)])!
    .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -50)

// Soft radial glow in the top-left for depth.
NSGradient(colors: [color(255, 255, 255, 0.20), color(255, 255, 255, 0)])!
    .draw(fromCenter: NSPoint(x: 220, y: 860), radius: 0, toCenter: NSPoint(x: 220, y: 860), radius: 620, options: [])

// Back card, slightly rotated, to suggest a wallet of cards.
context.saveGState()
context.translateBy(x: size / 2, y: size / 2)
context.rotate(by: 0.16)
let backCard = NSBezierPath(roundedRect: NSRect(x: -330, y: -170, width: 640, height: 400), xRadius: 70, yRadius: 70)
color(255, 255, 255, 0.28).setFill()
backCard.fill()
context.restoreGState()

// Front card with shadow.
let shadow = NSShadow()
shadow.shadowColor = color(0, 0, 0, 0.30)
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 40
NSGraphicsContext.saveGraphicsState()
shadow.set()
let cardRect = NSRect(x: 182, y: 262, width: 660, height: 440)
let card = NSBezierPath(roundedRect: cardRect, xRadius: 72, yRadius: 72)
color(255, 255, 255).setFill()
card.fill()
NSGraphicsContext.restoreGraphicsState()

// Card stripe.
let stripe = NSBezierPath(roundedRect: NSRect(x: cardRect.minX, y: cardRect.maxY - 150, width: cardRect.width, height: 70), xRadius: 0, yRadius: 0)
NSGraphicsContext.saveGraphicsState()
card.addClip()
color(18, 110, 96, 0.14).setFill()
stripe.fill()
NSGraphicsContext.restoreGraphicsState()

// Rupee symbol in a teal circle on the card.
let coin = NSRect(x: cardRect.minX + 70, y: cardRect.minY + 60, width: 210, height: 210)
color(18, 110, 96).setFill()
NSBezierPath(ovalIn: coin).fill()
let rupee = NSAttributedString(string: "₹", attributes: [
    .font: NSFont.systemFont(ofSize: 150, weight: .bold),
    .foregroundColor: NSColor.white,
])
let rupeeSize = rupee.size()
rupee.draw(at: NSPoint(x: coin.midX - rupeeSize.width / 2, y: coin.midY - rupeeSize.height / 2 + 4))

// Three "transaction" bars, the last one shorter, suggesting a ledger.
let barColor = color(18, 110, 96, 0.55)
for (index, width) in [250.0, 200.0, 140.0].enumerated() {
    let y = coin.maxY - 40 - CGFloat(index) * 62
    barColor.setFill()
    NSBezierPath(roundedRect: NSRect(x: coin.maxX + 50, y: y, width: width, height: 30), xRadius: 15, yRadius: 15).fill()
}

NSGraphicsContext.current = nil
guard let image = context.makeImage() else { fatalError("Could not render image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
try png.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
