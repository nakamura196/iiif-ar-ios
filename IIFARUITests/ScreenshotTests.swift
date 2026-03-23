import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    /// Capture the gallery screen (image list)
    func testCaptureGallery() throws {
        // Gallery should appear on launch
        sleep(3) // Wait for thumbnails to load

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "01_gallery"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Capture the image detail screen
    func testCaptureImageDetail() throws {
        sleep(2)

        // Tap the first sample image in the list
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            sleep(1)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "02_image_detail"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// Capture the settings screen
    func testCaptureSettings() throws {
        sleep(2)

        // Close the gallery sheet first
        let closeButton = app.buttons["閉じる"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
            sleep(1)
        }

        // Tap settings button
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'gearshape' OR label CONTAINS '設定'")).firstMatch
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
            sleep(1)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "03_settings"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    /// Capture the AR view with camera (requires real device)
    func testCaptureARView() throws {
        sleep(2)

        // Close gallery
        let closeButton = app.buttons["閉じる"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
            sleep(2)
        }

        // The AR camera view should now be visible
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "04_ar_camera"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Capture Add Image screen
    func testCaptureAddImage() throws {
        sleep(2)

        // Tap the + button in gallery
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'plus' OR label CONTAINS '追加'")).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            sleep(1)

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "05_add_image"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
