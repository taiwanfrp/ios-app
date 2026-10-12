import SwiftUI

/// Material Icons「SettingsSuggest」（Apache License 2.0），與 Android 版相同的圖示
struct SettingsSuggestShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var path = Path()
        path.move(to: p(17.41, 6.59))
        path.addLine(to: p(15, 5.5))
        path.addLine(to: p(17.41, 4.41))
        path.addLine(to: p(18.5, 2))
        path.addLine(to: p(19.59, 4.41))
        path.addLine(to: p(22, 5.5))
        path.addLine(to: p(19.59, 6.59))
        path.addLine(to: p(18.5, 9))
        path.addLine(to: p(17.41, 6.59))
        path.closeSubpath()
        path.move(to: p(21.28, 12.72))
        path.addLine(to: p(20.5, 11))
        path.addLine(to: p(19.72, 12.72))
        path.addLine(to: p(18, 13.5))
        path.addLine(to: p(19.72, 14.28))
        path.addLine(to: p(20.5, 16))
        path.addLine(to: p(21.28, 14.28))
        path.addLine(to: p(23, 13.5))
        path.addLine(to: p(21.28, 12.72))
        path.closeSubpath()
        path.move(to: p(16.24, 14.37))
        path.addLine(to: p(18.18, 15.84))
        path.addLine(to: p(15.68, 20.17))
        path.addLine(to: p(13.44, 19.23))
        path.addCurve(to: p(12.8, 19.6), control1: p(13.24, 19.36), control2: p(13.02, 19.49))
        path.addLine(to: p(12.5, 22))
        path.addLine(to: p(7.5, 22))
        path.addLine(to: p(7.2, 19.59))
        path.addCurve(to: p(6.56, 19.22), control1: p(6.98, 19.48), control2: p(6.77, 19.36))
        path.addLine(to: p(4.32, 20.16))
        path.addLine(to: p(1.82, 15.83))
        path.addLine(to: p(3.76, 14.36))
        path.addCurve(to: p(3.75, 14), control1: p(3.75, 14.25), control2: p(3.75, 14.12))
        path.addCurve(to: p(3.76, 13.63), control1: p(3.75, 13.88), control2: p(3.75, 13.75))
        path.addLine(to: p(1.82, 12.16))
        path.addLine(to: p(4.32, 7.83))
        path.addLine(to: p(6.56, 8.77))
        path.addCurve(to: p(7.2, 8.4), control1: p(6.76, 8.64), control2: p(6.98, 8.51))
        path.addLine(to: p(7.5, 6))
        path.addLine(to: p(12.5, 6))
        path.addLine(to: p(12.8, 8.41))
        path.addCurve(to: p(13.44, 8.78), control1: p(13.02, 8.52), control2: p(13.23, 8.64))
        path.addLine(to: p(15.68, 7.84))
        path.addLine(to: p(18.18, 12.17))
        path.addLine(to: p(16.24, 13.64))
        path.addCurve(to: p(16.25, 14.01), control1: p(16.25, 13.76), control2: p(16.25, 13.88))
        path.addCurve(to: p(16.24, 14.37), control1: p(16.25, 14.14), control2: p(16.25, 14.25))
        path.closeSubpath()
        path.move(to: p(13, 14))
        path.addCurve(to: p(10, 11), control1: p(13, 12.34), control2: p(11.66, 11))
        path.addCurve(to: p(7, 14), control1: p(8.34, 11), control2: p(7, 12.34))
        path.addCurve(to: p(10, 17), control1: p(7, 15.66), control2: p(8.34, 17))
        path.addCurve(to: p(13, 14), control1: p(11.66, 17), control2: p(13, 15.66))
        path.closeSubpath()
        return path
    }
}

/// Material Icons「GppBad」（Apache License 2.0），與 Android 版相同的圖示
struct GppBadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        var path = Path()
        path.move(to: p(12, 2))
        path.addLine(to: p(4, 5))
        path.addLine(to: p(4, 11.09))
        path.addCurve(to: p(12, 22), control1: p(4, 16.14), control2: p(7.41, 20.85))
        path.addCurve(to: p(20, 11.09), control1: p(16.59, 20.85), control2: p(20, 16.14))
        path.addLine(to: p(20, 5))
        path.addLine(to: p(12, 2))
        path.closeSubpath()
        path.move(to: p(15.5, 14.09))
        path.addLine(to: p(14.09, 15.5))
        path.addLine(to: p(12, 13.42))
        path.addLine(to: p(9.91, 15.5))
        path.addLine(to: p(8.5, 14.09))
        path.addLine(to: p(10.59, 12))
        path.addLine(to: p(8.5, 9.91))
        path.addLine(to: p(9.91, 8.5))
        path.addLine(to: p(12, 10.59))
        path.addLine(to: p(14.09, 8.5))
        path.addLine(to: p(15.5, 9.91))
        path.addLine(to: p(13.42, 12))
        path.addLine(to: p(15.5, 14.09))
        path.closeSubpath()
        return path
    }
}

