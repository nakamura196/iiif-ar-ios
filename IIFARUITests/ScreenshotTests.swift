import XCTest

final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()
    let outputDir = "/tmp/iifar_screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        app.launch()
    }

    private func saveScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let path = "\(outputDir)/\(name).png"
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
    }

    func testCaptureGallery() throws {
        sleep(5) // Wait for thumbnails
        saveScreenshot(name: "01_gallery")
    }

    func testCaptureImageDetail() throws {
        sleep(3)
        let firstCell = app.cells.firstMatch
        if firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            sleep(2)
            saveScreenshot(name: "02_image_detail")
        }
    }

    func testCaptureSettings() throws {
        sleep(2)
        let closeButton = app.buttons["閉じる"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
            sleep(1)
        }
        // Find settings gear button
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            if button.label.contains("gearshape") || button.label.contains("設定") {
                button.tap()
                sleep(1)
                saveScreenshot(name: "03_settings")
                return
            }
        }
    }

    func testCaptureAddImage() throws {
        sleep(2)
        // Tap + button in gallery toolbar
        let addButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add' OR label CONTAINS 'plus'")).firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
            sleep(1)
            saveScreenshot(name: "04_add_image")
        }
    }
}
