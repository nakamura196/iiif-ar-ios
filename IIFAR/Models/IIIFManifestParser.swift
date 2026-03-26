import Foundation

/// Parses a IIIF Presentation API 3.0 Manifest JSON into an `IIIFManifest`.
struct IIIFManifestParser {

    // MARK: - Public

    /// Parse a IIIF Manifest JSON dictionary and return an `IIIFManifest`,
    /// or `nil` if essential fields (canvas dimensions, IIIF service URL) are missing.
    static func parse(json: [String: Any]) -> IIIFManifest? {
        let label = extractLabel(from: json)

        // Extract first canvas
        guard let items = json["items"] as? [[String: Any]],
              let canvas = items.first else { return nil }

        let pixelWidth = canvas["width"] as? Int ?? 0
        let pixelHeight = canvas["height"] as? Int ?? 0

        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        // Extract IIIF Image Service URL
        guard let serviceURL = extractIIIFServiceURL(from: canvas) else { return nil }

        // Extract physical dimensions
        let (realWidthCm, realHeightCm) = extractPhysicalDimensions(
            from: json,
            canvas: canvas,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
        )

        let summary = extractSummary(from: json)

        return IIIFManifest(
            label: label,
            summary: summary,
            canvasWidth: pixelWidth,
            canvasHeight: pixelHeight,
            iiifServiceURL: serviceURL,
            realWidthCm: realWidthCm,
            realHeightCm: realHeightCm
        )
    }

    // MARK: - Label / Summary extraction

    /// Extract a display label from a IIIF `label` property (multilingual map).
    static func extractLabel(from dict: [String: Any]) -> String {
        if let label = dict["label"] as? [String: [String]] {
            return label["ja"]?.first ?? label["en"]?.first ?? label["none"]?.first ?? ""
        }
        if let label = dict["label"] as? String {
            return label
        }
        return ""
    }

    /// Extract a display summary from a IIIF `summary` property.
    static func extractSummary(from dict: [String: Any]) -> String? {
        if let summary = dict["summary"] as? [String: [String]] {
            return summary["ja"]?.first ?? summary["en"]?.first ?? summary["none"]?.first
        }
        if let summary = dict["summary"] as? String {
            return summary
        }
        return nil
    }

    // MARK: - IIIF Image Service URL

    /// Walk the canvas structure: canvas > items (AnnotationPage) > items (Annotation) > body > service
    /// to find the IIIF Image API service `@id` or `id`.
    static func extractIIIFServiceURL(from canvas: [String: Any]) -> String? {
        // canvas.items = AnnotationPages
        guard let annotationPages = canvas["items"] as? [[String: Any]] else { return nil }

        for page in annotationPages {
            guard let annotations = page["items"] as? [[String: Any]] else { continue }
            for annotation in annotations {
                guard let body = annotation["body"] as? [String: Any] else { continue }

                // Check body.service directly
                if let url = serviceURL(from: body) {
                    return url
                }

                // Some manifests nest the image inside body.items (choice)
                if let bodyItems = body["items"] as? [[String: Any]] {
                    for item in bodyItems {
                        if let url = serviceURL(from: item) {
                            return url
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Extract the IIIF Image API service URL from a resource dict that has a `service` key.
    private static func serviceURL(from resource: [String: Any]) -> String? {
        // `service` can be an array or a single object
        let services: [[String: Any]]
        if let arr = resource["service"] as? [[String: Any]] {
            services = arr
        } else if let obj = resource["service"] as? [String: Any] {
            services = [obj]
        } else {
            return nil
        }

        for service in services {
            // Check type/profile for IIIF Image API
            let type = service["type"] as? String ?? ""
            let profile = service["profile"] as? String ?? ""
            let isImageService = type.contains("ImageService")
                || profile.contains("iiif.io/api/image")
                || profile.contains("level")

            if isImageService {
                // Prefer @id (IIIF 2), fall back to id (IIIF 3)
                if let id = service["@id"] as? String {
                    return id.trimmingSuffix("/")
                }
                if let id = service["id"] as? String {
                    return id.trimmingSuffix("/")
                }
            }
        }

        // Fallback: return the first service with an id
        for service in services {
            if let id = service["@id"] as? String {
                return id.trimmingSuffix("/")
            }
            if let id = service["id"] as? String {
                return id.trimmingSuffix("/")
            }
        }

        return nil
    }

    // MARK: - Physical dimensions

    /// Extract physical dimensions in centimeters from the manifest or canvas.
    ///
    /// Tries these sources in order:
    /// 1. `x-physical-dimensions` on the manifest with `widthCm`/`heightCm`
    /// 2. `x-physical-dimensions` on the canvas
    /// 3. Canvas `service` with a `physdim` profile (physicalScale in metres per pixel)
    /// 4. Fallback: assume 0.01 cm per pixel
    static func extractPhysicalDimensions(
        from manifest: [String: Any],
        canvas: [String: Any],
        pixelWidth: Int,
        pixelHeight: Int
    ) -> (Double, Double) {
        // 1. x-physical-dimensions on manifest
        if let dims = parsePhysicalDimensions(from: manifest, pixelWidth: pixelWidth, pixelHeight: pixelHeight) {
            return dims
        }

        // 2. x-physical-dimensions on canvas
        if let dims = parsePhysicalDimensions(from: canvas, pixelWidth: pixelWidth, pixelHeight: pixelHeight) {
            return dims
        }

        // 3. Canvas service with physdim profile
        if let dims = parsePhysDimService(from: canvas, pixelWidth: pixelWidth, pixelHeight: pixelHeight) {
            return dims
        }

        // 4. Fallback: 0.01 cm per pixel
        return (Double(pixelWidth) * 0.01, Double(pixelHeight) * 0.01)
    }

    /// Parse `x-physical-dimensions` extension.
    /// Supports `{ widthCm, heightCm }` and `{ physicalScale, physicalUnits }` formats.
    private static func parsePhysicalDimensions(
        from dict: [String: Any],
        pixelWidth: Int,
        pixelHeight: Int
    ) -> (Double, Double)? {
        guard let phys = dict["x-physical-dimensions"] as? [String: Any] else { return nil }

        // Direct cm values
        if let w = phys["widthCm"] as? Double, let h = phys["heightCm"] as? Double, w > 0, h > 0 {
            return (w, h)
        }

        // physicalScale + physicalUnits
        if let scale = phys["physicalScale"] as? Double, scale > 0 {
            let units = phys["physicalUnits"] as? String ?? "cm"
            let multiplier: Double
            switch units {
            case "mm": multiplier = 0.1
            case "cm": multiplier = 1.0
            case "m": multiplier = 100.0
            case "in": multiplier = 2.54
            default: multiplier = 1.0
            }
            let widthCm = Double(pixelWidth) * scale * multiplier
            let heightCm = Double(pixelHeight) * scale * multiplier
            return (widthCm, heightCm)
        }

        return nil
    }

    /// Parse a canvas service array for a PhysicalDimensions service.
    private static func parsePhysDimService(
        from canvas: [String: Any],
        pixelWidth: Int,
        pixelHeight: Int
    ) -> (Double, Double)? {
        let services: [[String: Any]]
        if let arr = canvas["service"] as? [[String: Any]] {
            services = arr
        } else if let obj = canvas["service"] as? [String: Any] {
            services = [obj]
        } else {
            return nil
        }

        for service in services {
            let profile = service["profile"] as? String ?? ""
            if profile.contains("physdim"),
               let scale = service["physicalScale"] as? Double, scale > 0 {
                let units = service["physicalUnits"] as? String ?? "cm"
                let multiplier: Double
                switch units {
                case "mm": multiplier = 0.1
                case "cm": multiplier = 1.0
                case "m": multiplier = 100.0
                case "in": multiplier = 2.54
                default: multiplier = 1.0
                }
                let widthCm = Double(pixelWidth) * scale * multiplier
                let heightCm = Double(pixelHeight) * scale * multiplier
                return (widthCm, heightCm)
            }
        }
        return nil
    }
}

// MARK: - String helper

private extension String {
    /// Remove a trailing "/" if present.
    func trimmingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        }
        return self
    }
}
