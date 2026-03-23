import UIKit

enum DummyImageGenerator {
    /// Generate a dummy image with grid, size labels, and scale markers
    static func generate(for sample: SampleImage, maxDimension: Int) -> UIImage {
        let aspect = Double(sample.pixelWidth) / Double(sample.pixelHeight)
        let width: CGFloat
        let height: CGFloat
        if aspect >= 1.0 {
            width = CGFloat(maxDimension)
            height = width / aspect
        } else {
            height = CGFloat(maxDimension)
            width = height * aspect
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)

            // Background color based on size
            let bgColor: UIColor
            switch sample.sizeLabel {
            case "小": bgColor = UIColor(red: 0.85, green: 0.93, blue: 0.85, alpha: 1)
            case "中": bgColor = UIColor(red: 0.93, green: 0.90, blue: 0.80, alpha: 1)
            case "大": bgColor = UIColor(red: 0.93, green: 0.85, blue: 0.85, alpha: 1)
            case "特大": bgColor = UIColor(red: 0.90, green: 0.80, blue: 0.93, alpha: 1)
            default: bgColor = .lightGray
            }
            bgColor.setFill()
            ctx.fill(rect)

            // Grid lines (every 10cm equivalent)
            let pxPer10cm = 10.0 / sample.cmPerPixelX
            let scale = Double(maxDimension) / Double(max(sample.pixelWidth, sample.pixelHeight))
            let gridSpacing = CGFloat(pxPer10cm * scale)

            if gridSpacing > 20 {
                UIColor.gray.withAlphaComponent(0.3).setStroke()
                let path = UIBezierPath()
                path.lineWidth = 1

                var x: CGFloat = 0
                while x <= width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                    x += gridSpacing
                }
                var y: CGFloat = 0
                while y <= height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                    y += gridSpacing
                }
                path.stroke()
            }

            // Border
            UIColor.darkGray.setStroke()
            let border = UIBezierPath(rect: rect.insetBy(dx: 2, dy: 2))
            border.lineWidth = 4
            border.stroke()

            // Center text
            let titleFont = UIFont.boldSystemFont(ofSize: min(width, height) * 0.08)
            let sizeFont = UIFont.systemFont(ofSize: min(width, height) * 0.05)
            let scaleFont = UIFont.monospacedSystemFont(ofSize: min(width, height) * 0.04, weight: .regular)

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle,
            ]
            let sizeAttrs: [NSAttributedString.Key: Any] = [
                .font: sizeFont,
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraphStyle,
            ]
            let scaleAttrs: [NSAttributedString.Key: Any] = [
                .font: scaleFont,
                .foregroundColor: UIColor.gray,
                .paragraphStyle: paragraphStyle,
            ]

            let title = sample.name as NSString
            let sizeText = sample.sizeDescription as NSString
            let scaleText = sample.scaleDescription as NSString
            let gridText = "グリッド: 10cm間隔" as NSString

            let centerY = height / 2 - min(width, height) * 0.12
            title.draw(in: CGRect(x: 0, y: centerY, width: width, height: min(width, height) * 0.1), withAttributes: titleAttrs)
            sizeText.draw(in: CGRect(x: 0, y: centerY + min(width, height) * 0.10, width: width, height: min(width, height) * 0.07), withAttributes: sizeAttrs)
            scaleText.draw(in: CGRect(x: 0, y: centerY + min(width, height) * 0.18, width: width, height: min(width, height) * 0.06), withAttributes: scaleAttrs)
            gridText.draw(in: CGRect(x: 0, y: centerY + min(width, height) * 0.24, width: width, height: min(width, height) * 0.06), withAttributes: scaleAttrs)
        }
    }
}
