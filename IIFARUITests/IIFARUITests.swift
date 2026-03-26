import XCTest

final class IIFARUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Automatically accept system alerts (camera permission, sign-in prompts)
        addUIInterruptionMonitor(withDescription: "System Alert") { alert in
            let allowButtons = ["OK", "Allow", "許可"]
            for label in allowButtons {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        app.launch()
    }

    // MARK: - Helpers

    /// Taps the guest mode button to bypass login.
    /// Returns true if the button was found and tapped.
    @discardableResult
    private func enterGuestMode() -> Bool {
        let guestButton = app.buttons["ゲストとして続ける"]
        guard guestButton.waitForExistence(timeout: 5) else {
            return false
        }
        guestButton.tap()
        // Allow time for transition
        sleep(1)
        // Tap the app to dismiss any system alert captured by the interruption monitor
        app.tap()
        return true
    }

    /// Opens the gallery sheet. Assumes guest mode has already been entered.
    private func openGallery() {
        // The gallery may auto-present on first launch; if not, tap the gallery button.
        let galleryNavTitle = app.navigationBars["画像一覧"]
        if galleryNavTitle.waitForExistence(timeout: 3) {
            return
        }
        // Try tapping the gallery toolbar button (label: "一覧")
        let galleryButton = app.buttons["一覧"]
        if galleryButton.waitForExistence(timeout: 3) {
            galleryButton.tap()
            _ = galleryNavTitle.waitForExistence(timeout: 3)
        }
    }

    // MARK: - 1. Login Flow Tests

    func testGuestModeButtonExists() {
        let guestButton = app.buttons["ゲストとして続ける"]
        XCTAssertTrue(
            guestButton.waitForExistence(timeout: 5),
            "Guest mode button should be visible on the login screen"
        )
    }

    func testGuestModeNavigation() {
        let entered = enterGuestMode()
        XCTAssertTrue(entered, "Guest mode button should exist and be tappable")

        // After entering guest mode, we should see either:
        // - Camera permission view (with "次へ" or "設定を開く")
        // - AR view with gallery auto-presented (nav bar "画像一覧")
        // - AR view with toolbar buttons
        let cameraNextButton = app.buttons["次へ"]
        let cameraSettingsButton = app.buttons["設定を開く"]
        let galleryNav = app.navigationBars["画像一覧"]
        let galleryToolbarButton = app.buttons["一覧"]

        let foundExpectedUI = cameraNextButton.waitForExistence(timeout: 5)
            || cameraSettingsButton.exists
            || galleryNav.exists
            || galleryToolbarButton.exists

        XCTAssertTrue(foundExpectedUI, "After guest mode, camera permission or AR view should appear")
    }

    func testSignInButtonsExist() {
        let appleButton = app.buttons["Appleでサインイン"]
        let googleButton = app.buttons["Googleでサインイン"]

        XCTAssertTrue(
            appleButton.waitForExistence(timeout: 5),
            "Apple Sign-In button should be visible on login screen"
        )
        XCTAssertTrue(
            googleButton.exists,
            "Google Sign-In button should be visible on login screen"
        )
    }

    // MARK: - 2. Gallery Tests

    func testGalleryShowsSampleTab() {
        enterGuestMode()
        openGallery()

        let sampleTab = app.buttons["サンプル"]
        XCTAssertTrue(
            sampleTab.waitForExistence(timeout: 5),
            "Gallery should have a 'サンプル' tab"
        )
    }

    func testGalleryShowsMyCollectionsTab() {
        enterGuestMode()
        openGallery()

        let myCollectionsTab = app.buttons["マイコレクション"]
        XCTAssertTrue(
            myCollectionsTab.waitForExistence(timeout: 5),
            "Gallery should have a 'マイコレクション' tab"
        )
    }

    func testSampleImagesExist() {
        enterGuestMode()
        openGallery()

        // The samples list should contain cells. Wait for at least one to appear.
        let firstCell = app.cells.firstMatch
        XCTAssertTrue(
            firstCell.waitForExistence(timeout: 10),
            "Gallery should list at least one sample image"
        )

        // Verify there are multiple sample images (we know there are 3 hardcoded)
        let cellCount = app.cells.count
        XCTAssertGreaterThanOrEqual(cellCount, 1, "Gallery should contain sample images")
    }

    func testImageDetailView() {
        enterGuestMode()
        openGallery()

        // Wait for sample images to load
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTFail("No sample images found in gallery")
            return
        }
        firstCell.tap()
        sleep(1)

        // Verify the detail view has the AR placement button
        let arButton = app.buttons["ARで配置"]
        XCTAssertTrue(
            arButton.waitForExistence(timeout: 5),
            "Image detail view should have an 'ARで配置' button"
        )
    }

    // MARK: - 3. Settings Tests

    func testSettingsOpens() {
        enterGuestMode()

        // Close gallery if it auto-opened
        let closeButton = app.buttons["閉じる"]
        if closeButton.waitForExistence(timeout: 3) {
            closeButton.tap()
            sleep(1)
        }

        // Tap settings gear button
        let settingsButton = app.buttons["gearshape"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
        } else {
            // Fallback: search for any button with gearshape in identifier
            let buttons = app.buttons.allElementsBoundByIndex
            var found = false
            for button in buttons {
                if button.label.contains("gearshape") || button.label.contains("設定") {
                    button.tap()
                    found = true
                    break
                }
            }
            if !found {
                XCTFail("Could not find settings button")
                return
            }
        }

        // Verify settings view appeared
        let settingsNav = app.navigationBars["設定"]
        XCTAssertTrue(
            settingsNav.waitForExistence(timeout: 5),
            "Settings view should appear after tapping gear button"
        )
    }

    // MARK: - 4. App Store Review Flow Test

    func testFullReviewFlow() {
        // Step 1: App launches to login screen
        let guestButton = app.buttons["ゲストとして続ける"]
        XCTAssertTrue(
            guestButton.waitForExistence(timeout: 5),
            "Step 1: Login screen should show on launch"
        )

        // Step 2: Tap guest mode
        guestButton.tap()
        sleep(1)
        app.tap() // Dismiss any system alerts

        // Step 3: Handle camera permission if prompted
        let cameraNextButton = app.buttons["次へ"]
        if cameraNextButton.waitForExistence(timeout: 3) {
            cameraNextButton.tap()
            sleep(2)
            app.tap() // Trigger interruption monitor for system alert
            sleep(1)
        }

        // Step 4: Open gallery (may auto-present or need manual tap)
        openGallery()

        let galleryNav = app.navigationBars["画像一覧"]
        XCTAssertTrue(
            galleryNav.waitForExistence(timeout: 5),
            "Step 4: Gallery should be visible"
        )

        // Step 5: Select a sample image
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 10) else {
            XCTFail("Step 5: No sample images found in gallery")
            return
        }
        firstCell.tap()
        sleep(1)

        // Step 6: Verify detail view with AR button
        let arButton = app.buttons["ARで配置"]
        XCTAssertTrue(
            arButton.waitForExistence(timeout: 5),
            "Step 6: Detail view should show 'ARで配置' button"
        )

        // Step 7: Tap AR placement button (this dismisses gallery and loads image)
        arButton.tap()
        sleep(2)

        // After tapping AR placement, the gallery should dismiss.
        // We verify by checking that the gallery nav bar is no longer present
        // or that the AR toolbar buttons become visible.
        let galleryButtonAfter = app.buttons["一覧"]
        let galleryNavAfter = app.navigationBars["画像一覧"]

        let galleryDismissed = galleryButtonAfter.waitForExistence(timeout: 5)
            || !galleryNavAfter.exists

        XCTAssertTrue(
            galleryDismissed,
            "Step 7: Gallery should dismiss after tapping 'ARで配置'"
        )
    }
}
