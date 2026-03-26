import Foundation
import FirebaseAnalytics

/// Lightweight wrapper around Firebase Analytics for tracking key user actions.
///
/// Usage: Call the static methods from Views or managers when events occur.
/// Tracking calls will be added to Views after the view refactoring stabilizes.
///
/// ## Crashlytics custom keys (to add in ARViewContainer.Coordinator later)
/// These keys would help diagnose AR-related crashes:
/// - "current_sample_id": The ID of the currently loaded SampleImage
/// - "current_sample_name": The name of the placed image
/// - "is_placed": Whether an image is currently placed in the AR scene
/// - "zoom_level": Current tile zoom level (scale factor)
/// - "camera_distance": Distance from camera to placed image anchor
/// - "visible_tile_count": Number of tiles currently visible
/// - "device_supports_mesh": Whether the device supports scene reconstruction
enum AnalyticsManager {

    // MARK: - Event Names

    private enum Event {
        static let imageSelected = "image_selected"
        static let arPlaced = "ar_placed"
        static let collectionLoaded = "collection_loaded"
        static let tipPurchased = "tip_purchased"
    }

    // MARK: - Parameter Names

    private enum Param {
        static let imageId = "image_id"
        static let imageName = "image_name"
        static let imageWidth = "image_width_cm"
        static let imageHeight = "image_height_cm"
        static let collectionId = "collection_id"
        static let collectionName = "collection_name"
        static let itemCount = "item_count"
        static let tipProductId = "tip_product_id"
        static let tipPrice = "tip_price"
    }

    // MARK: - User Properties

    private enum UserProperty {
        static let loginMethod = "login_method"
        static let collectionCount = "collection_count"
    }

    // MARK: - Track Events

    /// Log when a user selects an image from the gallery.
    static func trackImageSelected(id: String, name: String, widthCm: Double, heightCm: Double) {
        Analytics.logEvent(Event.imageSelected, parameters: [
            Param.imageId: id,
            Param.imageName: name,
            Param.imageWidth: widthCm,
            Param.imageHeight: heightCm
        ])
    }

    /// Log when an image is placed in the AR scene.
    static func trackARPlaced(id: String, name: String) {
        Analytics.logEvent(Event.arPlaced, parameters: [
            Param.imageId: id,
            Param.imageName: name
        ])
    }

    /// Log when a IIIF collection/manifest is loaded.
    static func trackCollectionLoaded(id: String, name: String, itemCount: Int) {
        Analytics.logEvent(Event.collectionLoaded, parameters: [
            Param.collectionId: id,
            Param.collectionName: name,
            Param.itemCount: itemCount
        ])
    }

    /// Log when a tip is purchased via the Tip Jar.
    static func trackTipPurchased(productId: String, price: String) {
        Analytics.logEvent(Event.tipPurchased, parameters: [
            Param.tipProductId: productId,
            Param.tipPrice: price
        ])
    }

    // MARK: - User Properties

    /// Set how the user logged in (e.g., "google", "guest").
    static func setLoginMethod(_ method: String) {
        Analytics.setUserProperty(method, forName: UserProperty.loginMethod)
    }

    /// Set the number of collections the user has.
    static func setCollectionCount(_ count: Int) {
        Analytics.setUserProperty(String(count), forName: UserProperty.collectionCount)
    }
}
