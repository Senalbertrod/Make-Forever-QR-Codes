//
//  QRIcons.swift
//  Make Forever QR Codes
//
//  The small icons that can sit in the middle of a code. Drawn by the app
//  itself (simple shapes), so printed and shared codes are free to use.
//

import UIKit

enum QRIcons {
    /// Draws the icon for a kind of code inside a square `rect`.
    /// Must be called while drawing an image (UIGraphicsImageRenderer).
    static func draw(_ type: CodeType, in rect: CGRect, color: UIColor, background: UIColor) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let c = IconCanvas(rect: rect, ctx: ctx, ink: color, paper: background)
        switch type {
        case .link: c.link()
        case .contact: c.card()
        case .social: c.thumbsUp()
        case .wifi: c.wifi()
        case .text: c.bubble()
        case .phone: c.handset()
        case .message: c.chat()
        case .email: c.envelope()
        case .location: c.pin()
        case .event: c.calendar()
        }
    }
}

/// Shapes in a 0...1 box (0,0 = top left), scaled into `rect`.
private struct IconCanvas {
    let rect: CGRect
    let ctx: CGContext
    let ink: UIColor
    let paper: UIColor

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    func s(_ v: CGFloat) -> CGFloat { v * rect.width }
    func box(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGRect {
        CGRect(origin: p(x1, y1), size: CGSize(width: s(x2 - x1), height: s(y2 - y1)))
    }
    func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }

    // MARK: Building blocks

    func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor? = nil) {
        (color ?? ink).setFill()
        UIBezierPath(arcCenter: p(x, y), radius: s(r), startAngle: 0, endAngle: 2 * .pi, clockwise: true).fill()
    }

    func ring(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, width: CGFloat) {
        let path = UIBezierPath(arcCenter: p(x, y), radius: s(r), startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        path.lineWidth = s(width)
        ink.setStroke()
        path.stroke()
    }

    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, width: CGFloat, _ color: UIColor? = nil) {
        let path = UIBezierPath()
        path.move(to: p(x1, y1))
        path.addLine(to: p(x2, y2))
        path.lineWidth = s(width)
        path.lineCapStyle = .round
        (color ?? ink).setStroke()
        path.stroke()
    }

    /// An arc; angles in degrees, 0 = right, 90 = down, 270 = up.
    func arc(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, from a1: CGFloat, to a2: CGFloat, width: CGFloat) {
        let path = UIBezierPath(arcCenter: p(x, y), radius: s(r),
                                startAngle: radians(a1), endAngle: radians(a2), clockwise: true)
        path.lineWidth = s(width)
        path.lineCapStyle = .round
        ink.setStroke()
        path.stroke()
    }

    func fillRounded(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, radius: CGFloat) {
        ink.setFill()
        UIBezierPath(roundedRect: box(x1, y1, x2, y2), cornerRadius: s(radius)).fill()
    }

    func strokeRounded(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, radius: CGFloat, width: CGFloat) {
        let path = UIBezierPath(roundedRect: box(x1, y1, x2, y2), cornerRadius: s(radius))
        path.lineWidth = s(width)
        ink.setStroke()
        path.stroke()
    }

    // MARK: The icons

    func wifi() {
        dot(0.5, 0.78, 0.08)
        for r: CGFloat in [0.25, 0.42, 0.59] {
            arc(0.5, 0.80, r, from: 225, to: 315, width: 0.1)
        }
    }

    /// Two chain links, tilted.
    func link() {
        ctx.saveGState()
        let center = p(0.5, 0.5)
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: -.pi / 4)
        ink.setStroke()
        for offset: CGFloat in [-0.17, 0.17] {
            let pill = CGRect(x: s(offset - 0.22), y: s(-0.12), width: s(0.44), height: s(0.24))
            let path = UIBezierPath(roundedRect: pill, cornerRadius: s(0.12))
            path.lineWidth = s(0.09)
            path.stroke()
        }
        ctx.restoreGState()
    }

    /// A contact card: a person and two lines.
    func card() {
        strokeRounded(0.08, 0.2, 0.92, 0.8, radius: 0.1, width: 0.08)
        dot(0.33, 0.42, 0.095)
        // Shoulders: the top half of an oval.
        ctx.saveGState()
        ctx.clip(to: box(0, 0, 1, 0.69))
        ink.setFill()
        UIBezierPath(ovalIn: box(0.17, 0.57, 0.49, 0.81)).fill()
        ctx.restoreGState()
        line(0.55, 0.42, 0.79, 0.42, width: 0.075)
        line(0.55, 0.58, 0.72, 0.58, width: 0.075)
    }

    /// A thumbs up (the "like" sign).
    func thumbsUp() {
        fillRounded(0.08, 0.42, 0.29, 0.93, radius: 0.06)
        let points: [(CGFloat, CGFloat)] = [
            (0.37, 0.93), (0.37, 0.45), (0.53, 0.22), (0.55, 0.12), (0.60, 0.08), (0.66, 0.12),
            (0.66, 0.20), (0.62, 0.36), (0.86, 0.36), (0.92, 0.43), (0.84, 0.87), (0.78, 0.93),
        ]
        let hand = UIBezierPath()
        hand.move(to: p(points[0].0, points[0].1))
        for point in points.dropFirst() { hand.addLine(to: p(point.0, point.1)) }
        hand.close()
        // Filling and outlining with round corners softens the shape.
        hand.lineWidth = s(0.07)
        hand.lineJoinStyle = .round
        ink.setFill()
        ink.setStroke()
        hand.fill()
        hand.stroke()
    }

    /// A speech bubble with two lines of text.
    func bubble() {
        fillRounded(0.08, 0.14, 0.92, 0.70, radius: 0.17)
        let tail = UIBezierPath()
        tail.move(to: p(0.24, 0.62))
        tail.addLine(to: p(0.18, 0.90))
        tail.addLine(to: p(0.48, 0.66))
        tail.close()
        ink.setFill()
        tail.fill()
        line(0.28, 0.35, 0.72, 0.35, width: 0.08, paper)
        line(0.28, 0.51, 0.58, 0.51, width: 0.08, paper)
    }

    /// A mobile phone.
    func handset() {
        strokeRounded(0.27, 0.07, 0.73, 0.93, radius: 0.11, width: 0.08)
        line(0.43, 0.19, 0.57, 0.19, width: 0.06)
        dot(0.5, 0.80, 0.05)
    }

    /// A message bubble with three dots ("typing").
    func chat() {
        fillRounded(0.06, 0.14, 0.94, 0.72, radius: 0.29)
        let tail = UIBezierPath()
        tail.move(to: p(0.20, 0.62))
        tail.addLine(to: p(0.12, 0.92))
        tail.addLine(to: p(0.44, 0.68))
        tail.close()
        ink.setFill()
        tail.fill()
        for x: CGFloat in [0.30, 0.5, 0.70] {
            dot(x, 0.43, 0.065, paper)
        }
    }

    /// An envelope.
    func envelope() {
        strokeRounded(0.08, 0.22, 0.92, 0.78, radius: 0.08, width: 0.08)
        let flap = UIBezierPath()
        flap.move(to: p(0.13, 0.28))
        flap.addLine(to: p(0.5, 0.56))
        flap.addLine(to: p(0.87, 0.28))
        flap.lineWidth = s(0.08)
        flap.lineCapStyle = .round
        flap.lineJoinStyle = .round
        ink.setStroke()
        flap.stroke()
    }

    /// A map pin with a hole.
    func pin() {
        let cx: CGFloat = 0.5, cy: CGFloat = 0.39, r: CGFloat = 0.31, tip: CGFloat = 0.95
        // Where the straight sides touch the circle.
        let phi = acos(r / (tip - cy)) * 180 / .pi
        let path = UIBezierPath()
        path.move(to: p(cx, tip))
        path.addArc(withCenter: p(cx, cy), radius: s(r),
                    startAngle: radians(90 + phi), endAngle: radians(90 - phi + 360), clockwise: true)
        path.close()
        ink.setFill()
        path.fill()
        dot(cx, cy, 0.12, paper)
    }

    /// A calendar page.
    func calendar() {
        strokeRounded(0.1, 0.2, 0.9, 0.9, radius: 0.11, width: 0.08)
        fillRounded(0.06, 0.16, 0.94, 0.40, radius: 0.13)
        ink.setFill()
        UIRectFill(box(0.06, 0.30, 0.94, 0.40))
        line(0.32, 0.07, 0.32, 0.24, width: 0.09)
        line(0.68, 0.07, 0.68, 0.24, width: 0.09)
        for x: CGFloat in [0.31, 0.5, 0.69] {
            for y: CGFloat in [0.57, 0.75] {
                dot(x, y, 0.055)
            }
        }
    }
}
