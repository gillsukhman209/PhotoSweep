import AppKit
import CoreGraphics
import Foundation

struct Shot {
    let file: String
    let eyebrow: String
    let headline: String
    let accent: String
    let subhead: String
    let hero: String
    let chips: [String]
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let heroRoot = root.appendingPathComponent("AppStoreAssets/GeneratedHeroes")
let screenshot65 = root.appendingPathComponent("AppStoreAssets/Screenshots/6.5-inch")
let screenshot69 = root.appendingPathComponent("AppStoreAssets/Screenshots/6.9-inch")
let upload65 = root.appendingPathComponent("AppStoreAssets/Upload/6.5-inch")
let upload69 = root.appendingPathComponent("AppStoreAssets/Upload/6.9-inch")
let appIcon = NSImage(contentsOf: root.appendingPathComponent("PhotoSweep/Assets.xcassets/AppIcon.appiconset/PhotoSweepIcon.png"))
var canvasHeight: CGFloat = 0

let shots = [
    Shot(
        file: "01-swipe-cleanup",
        eyebrow: "FAST PHOTO CLEANUP",
        headline: "Clean photos with a swipe",
        accent: "swipe",
        subhead: "Left to delete. Right to keep. Review everything before it’s removed.",
        hero: "swipe.png",
        chips: ["Swipe review", "Keep or delete", "Undo anytime"]
    ),
    Shot(
        file: "02-duplicates",
        eyebrow: "DUPLICATE FINDER",
        headline: "Delete duplicate copies fast",
        accent: "duplicate",
        subhead: "Keep the best shot and clear the extra copies in each set.",
        hero: "duplicates.png",
        chips: ["Find copies", "Keep one", "Delete extras"]
    ),
    Shot(
        file: "03-free-space",
        eyebrow: "MAKE ROOM AGAIN",
        headline: "Free up to 200GB",
        accent: "200GB",
        subhead: "Find videos, screenshots, and old clutter taking over your iPhone.",
        hero: "storage.png",
        chips: ["Photos", "Videos", "Screenshots"]
    ),
    Shot(
        file: "04-skip-ahead",
        eyebrow: "REVIEW FASTER",
        headline: "Jump through your library",
        accent: "Jump",
        subhead: "Preview what’s next and skip ahead when you already know what to keep.",
        hero: "skip.png",
        chips: ["Next photos", "Date jump", "Trip cleanup"]
    ),
    Shot(
        file: "05-private",
        eyebrow: "PRIVATE BY DESIGN",
        headline: "Your photos stay on device",
        accent: "device",
        subhead: "PhotoSweep scans locally. Your library is not uploaded by the app.",
        hero: "privacy.png",
        chips: ["On-device", "No uploads", "Review first"]
    )
]

let sizes: [(screenshots: URL, upload: URL, size: CGSize)] = [
    (screenshot65, upload65, CGSize(width: 1284, height: 2778)),
    (screenshot69, upload69, CGSize(width: 1290, height: 2796))
]

for target in sizes {
    try FileManager.default.createDirectory(at: target.screenshots, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target.upload, withIntermediateDirectories: true)

    for shot in shots {
        let image = renderScreenshot(size: target.size, shot: shot)
        try savePNG(image, to: target.screenshots.appendingPathComponent("\(shot.file).png"))
        try saveJPEG(image, to: target.screenshots.appendingPathComponent("\(shot.file).jpg"), quality: 0.94)
        try saveJPEG(image, to: target.upload.appendingPathComponent("\(shot.file).jpg"), quality: 0.94)
    }
}

func renderScreenshot(size: CGSize, shot: Shot) -> NSImage {
    guard let hero = NSImage(contentsOf: heroRoot.appendingPathComponent(shot.hero)) else {
        fatalError("Missing hero image: \(shot.hero)")
    }

    let image = NSImage(size: size)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
    canvasHeight = size.height
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    drawBackground(ctx, size: size)

    let heroRect = CGRect(
        x: -size.width * 0.06,
        y: size.height * 0.37,
        width: size.width * 1.12,
        height: size.height * 0.69
    )
    drawImageCover(hero, in: heroRect)

    drawTopScrim(ctx, size: size)
    drawBrand(size: size)

    let margin = size.width * 0.072
    drawText(
        shot.eyebrow,
        rect: CGRect(x: margin, y: size.height * 0.125, width: size.width - margin * 2, height: 42),
        fontSize: 27,
        weight: .black,
        color: NSColor(red: 0.39, green: 0.98, blue: 0.80, alpha: 1),
        align: .left,
        kern: 1.4
    )

    drawHeadline(shot, margin: margin, y: size.height * 0.167, width: size.width - margin * 2)

    drawText(
        shot.subhead,
        rect: CGRect(x: margin, y: size.height * 0.300, width: size.width - margin * 2, height: 116),
        fontSize: 39,
        weight: .bold,
        color: NSColor.white.withAlphaComponent(0.78),
        align: .left
    )

    drawBottomGradient(ctx, size: size)

    image.unlockFocus()
    return image
}

func drawBackground(_ ctx: CGContext, size: CGSize) {
    let colors = [
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 1).cgColor,
        NSColor(red: 0.030, green: 0.050, blue: 0.105, alpha: 1).cgColor,
        NSColor(red: 0.040, green: 0.020, blue: 0.090, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.54, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size.width, y: size.height),
        options: []
    )

    drawGlow(ctx, center: CGPoint(x: size.width * 0.14, y: size.height * 0.20), radius: size.width * 0.68, color: NSColor(red: 0.00, green: 0.85, blue: 0.66, alpha: 0.22))
    drawGlow(ctx, center: CGPoint(x: size.width * 0.96, y: size.height * 0.42), radius: size.width * 0.80, color: NSColor(red: 0.38, green: 0.23, blue: 1.00, alpha: 0.24))
    drawGlow(ctx, center: CGPoint(x: size.width * 0.58, y: size.height * 0.90), radius: size.width * 0.56, color: NSColor(red: 0.10, green: 0.45, blue: 1.00, alpha: 0.17))
}

func drawTopScrim(_ ctx: CGContext, size: CGSize) {
    let colors = [
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 1.00).cgColor,
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 0.98).cgColor,
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 0.18).cgColor,
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 0.00).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.48, 0.84, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size.height),
        end: CGPoint(x: 0, y: size.height * 0.46),
        options: []
    )
}

func drawBottomGradient(_ ctx: CGContext, size: CGSize) {
    let colors = [
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 0.00).cgColor,
        NSColor(red: 0.016, green: 0.022, blue: 0.046, alpha: 0.55).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size.height * 0.50),
        end: CGPoint(x: 0, y: 0),
        options: []
    )
}

func drawGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: NSColor) {
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsAfterEndLocation]
    )
}

func drawBrand(size: CGSize) {
    let margin = size.width * 0.072
    let y = size.height * 0.062
    let iconSize: CGFloat = 70

    if let appIcon {
        drawImage(appIcon, in: CGRect(x: margin, y: y, width: iconSize, height: iconSize), cornerRadius: 18)
    }

    drawText(
        "PhotoSweep",
        rect: CGRect(x: margin + iconSize + 18, y: y + 5, width: 430, height: 42),
        fontSize: 32,
        weight: .black,
        color: .white,
        align: .left
    )
    drawText(
        "Photo cleaner",
        rect: CGRect(x: margin + iconSize + 18, y: y + 43, width: 430, height: 34),
        fontSize: 22,
        weight: .heavy,
        color: NSColor.white.withAlphaComponent(0.55),
        align: .left
    )
}

func drawHeadline(_ shot: Shot, margin: CGFloat, y: CGFloat, width: CGFloat) {
    let parts = shot.headline.components(separatedBy: shot.accent)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .left
    paragraph.lineBreakMode = .byWordWrapping

    let headline = NSMutableAttributedString()
    let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 82, weight: .black),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph
    ]
    let accentAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 82, weight: .black),
        .foregroundColor: NSColor(red: 0.34, green: 0.77, blue: 1.00, alpha: 1),
        .paragraphStyle: paragraph
    ]

    if parts.count == 2 {
        headline.append(NSAttributedString(string: parts[0], attributes: baseAttrs))
        headline.append(NSAttributedString(string: shot.accent, attributes: accentAttrs))
        headline.append(NSAttributedString(string: parts[1], attributes: baseAttrs))
    } else {
        headline.append(NSAttributedString(string: shot.headline, attributes: baseAttrs))
    }

    headline.draw(in: topRect(CGRect(x: margin, y: y, width: width, height: 210)))
}

func drawChips(_ chips: [String], size: CGSize, top: CGFloat) {
    let margin = size.width * 0.072
    var x = margin
    let gap: CGFloat = 14

    for chip in chips {
        let width = min(size.width - margin * 2, CGFloat(chip.count) * 18 + 74)
        let rect = CGRect(x: x, y: top, width: width, height: 58)
        drawText(
            chip,
            rect: rect.insetBy(dx: 0, dy: 13),
            fontSize: 21,
            weight: .black,
            color: .white,
            align: .center,
            background: NSColor.white.withAlphaComponent(0.105),
            radius: 29
        )
        x += width + gap
    }
}

func drawImageCover(_ image: NSImage, in rect: CGRect) {
    guard image.size.width > 0, image.size.height > 0 else { return }
    let imageRatio = image.size.width / image.size.height
    let rectRatio = rect.width / rect.height
    var drawRect = rect

    if imageRatio > rectRatio {
        drawRect.size.width = rect.height * imageRatio
        drawRect.origin.x = rect.midX - drawRect.width / 2
    } else {
        drawRect.size.height = rect.width / imageRatio
        drawRect.origin.y = rect.midY - drawRect.height / 2
    }

    drawImage(image, in: drawRect, cornerRadius: 0)
}

func drawImage(_ image: NSImage, in rect: CGRect, cornerRadius: CGFloat) {
    let rect = topRect(rect)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    if cornerRadius > 0 {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
        ctx.clip()
    }
    image.draw(in: rect)
    ctx.restoreGState()
}

func drawText(
    _ text: String,
    rect: CGRect,
    fontSize: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    align: NSTextAlignment,
    background: NSColor? = nil,
    radius: CGFloat = 0,
    kern: CGFloat = 0
) {
    let rect = topRect(rect)
    if let background {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(background.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
    }

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph,
        .kern: kern
    ]
    NSString(string: text).draw(in: rect, withAttributes: attributes)
}

func topRect(_ rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: canvasHeight - rect.maxY, width: rect.width, height: rect.height)
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    try png.write(to: url)
}

func saveJPEG(_ image: NSImage, to url: URL, quality: CGFloat) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let jpg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
        fatalError("Could not encode JPEG")
    }
    try jpg.write(to: url)
}
