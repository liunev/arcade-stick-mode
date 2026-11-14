// Draws the app icon: a toggle switch whose knob is an arcade push button.
// Usage: swift Resources/make-icon.swift <output.png>   (1024 x 1024)
import AppKit

let S: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                            CGFloat(hex & 0xFF) / 255, a])!
}
func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map { $0.1 } as CFArray, locations: stops.map { $0.0 })!
}
func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
}
func clipped(_ path: CGPath, _ body: () -> Void) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip(); body(); ctx.restoreGState()
}

// --- Tile: the standard macOS rounded square with a soft drop shadow ---------
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tile = CGPath(roundedRect: tileRect, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(tile); ctx.setFillColor(rgb(0x171A2B)); ctx.fillPath()
ctx.restoreGState()
clipped(tile) {
    // Cabinet-panel background: deep indigo fading to near black
    ctx.drawLinearGradient(gradient([(0, rgb(0x343A63)), (1, rgb(0x10111C))]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Soft glow behind the lit side of the switch
    ctx.drawRadialGradient(gradient([(0, rgb(0xFF4B3A, 0.30)), (1, rgb(0xFF4B3A, 0))]),
                           startCenter: CGPoint(x: 662, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 662, y: 512), endRadius: 420, options: [])
    // Top edge highlight
    ctx.addPath(CGPath(roundedRect: tileRect.insetBy(dx: 3, dy: 3), cornerWidth: 183, cornerHeight: 183, transform: nil))
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.10)); ctx.setLineWidth(6); ctx.strokePath()
}

// --- Switch track -------------------------------------------------------------
let trackRect = CGRect(x: 192, y: 352, width: 640, height: 320)
let track = CGPath(roundedRect: trackRect, cornerWidth: 160, cornerHeight: 160, transform: nil)
let offCenter = CGPoint(x: 352, y: 512)   // empty position (Switch mode)
let onCenter = CGPoint(x: 672, y: 512)    // button position (Fightcade mode)

clipped(track) {
    ctx.drawLinearGradient(gradient([(0, rgb(0x07080D)), (1, rgb(0x191C2E))]),
                           start: CGPoint(x: 512, y: 672), end: CGPoint(x: 512, y: 352), options: [])
    // Lit half of the track, fading out toward the empty side
    ctx.drawLinearGradient(gradient([(0, rgb(0xFF5A3C, 0)), (1, rgb(0xFF5A3C, 0.55))]),
                           start: CGPoint(x: 330, y: 512), end: CGPoint(x: 832, y: 512), options: [])
    // Inner shadow along the top lip so the track reads as recessed
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: rgb(0x000000, 0.9))
    ctx.addPath(CGPath(roundedRect: trackRect.insetBy(dx: -20, dy: -20), cornerWidth: 180, cornerHeight: 180, transform: nil))
    ctx.setStrokeColor(rgb(0x000000)); ctx.setLineWidth(40); ctx.strokePath()
}
ctx.addPath(track); ctx.setStrokeColor(rgb(0xFFFFFF, 0.14)); ctx.setLineWidth(5); ctx.strokePath()

// Empty button socket on the "off" side
ctx.addPath(circle(offCenter, 96)); ctx.setStrokeColor(rgb(0xFFFFFF, 0.16)); ctx.setLineWidth(10); ctx.strokePath()
ctx.addPath(circle(offCenter, 62)); ctx.setStrokeColor(rgb(0xFFFFFF, 0.09)); ctx.setLineWidth(8); ctx.strokePath()

// --- Knob: an arcade push button seen from above -------------------------------
let rimR: CGFloat = 138, plungerR: CGFloat = 98
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 30, color: rgb(0x000000, 0.65))
ctx.addPath(circle(onCenter, rimR)); ctx.setFillColor(rgb(0xB3171C)); ctx.fillPath()
ctx.restoreGState()
// Rim: lighter at the top, darker at the bottom
clipped(circle(onCenter, rimR)) {
    ctx.drawLinearGradient(gradient([(0, rgb(0xFF6A5C)), (0.5, rgb(0xD9242A)), (1, rgb(0x8E0F16))]),
                           start: CGPoint(x: onCenter.x, y: onCenter.y + rimR),
                           end: CGPoint(x: onCenter.x, y: onCenter.y - rimR), options: [])
}
// Gap between rim and plunger
ctx.addPath(circle(onCenter, plungerR + 9)); ctx.setFillColor(rgb(0x5E070C)); ctx.fillPath()
// Plunger: domed, with the highlight up and to the left
clipped(circle(onCenter, plungerR)) {
    let hot = CGPoint(x: onCenter.x - 30, y: onCenter.y + 38)
    ctx.drawRadialGradient(gradient([(0, rgb(0xFF8274)), (0.45, rgb(0xEE2F33)), (1, rgb(0xB5141B))]),
                           startCenter: hot, startRadius: 0, endCenter: onCenter, endRadius: plungerR,
                           options: [.drawsAfterEndLocation])
}
// Specular glint
ctx.saveGState()
ctx.translateBy(x: onCenter.x - 34, y: onCenter.y + 52); ctx.rotate(by: .pi / 7)
ctx.addPath(CGPath(ellipseIn: CGRect(x: -34, y: -15, width: 68, height: 30), transform: nil))
ctx.setFillColor(rgb(0xFFFFFF, 0.42)); ctx.fillPath()
ctx.restoreGState()

// --- Write PNG ---------------------------------------------------------------
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
