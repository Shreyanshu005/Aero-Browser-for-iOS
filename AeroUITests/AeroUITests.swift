//
//  AeroUITests.swift
//  AeroUITests
//
//  Created by Shreyanshu on 08/05/26.
//

import XCTest

final class AeroUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    @MainActor
    func testLaunchShowsBrowserChromeAndCanReachNewTabSurface() throws {
        launchApp()

        waitForElement(app.element(AeroUI.addressBarDisplay), "Expected browser address bar on launch")
        waitForElement(app.buttons[AeroUI.toolbarTabs], "Expected tab grid button on launch")
        waitForElement(app.buttons[AeroUI.toolbarMenu], "Expected menu button on launch")

        openTabGrid()
        tapNewTabInTabGrid()

        waitForElement(app.element(AeroUI.newTabTitle), "Expected new tab page after creating a tab")
        waitForElement(app.textFields[AeroUI.addressBarTextField], "Expected new tab to focus address entry")
    }

    @MainActor
    func testAddressBarFocusAcceptsSearchText() throws {
        launchApp()
        openTabGrid()
        tapNewTabInTabGrid()

        waitForElement(app.buttons[AeroUI.addressBarCancel], "Expected cancel button after new tab focus").tap()
        focusAddressBar()

        let query = "openai browser testing"
        let addressField = waitForElement(
            app.textFields[AeroUI.addressBarTextField],
            "Expected focused address text field"
        )

        addressField.typeText(query)

        XCTAssertEqual(addressField.value as? String, query)
    }

    @MainActor
    func testTabGridOpensAndCreatesFocusedNewTab() throws {
        launchApp()

        openTabGrid()
        waitForElement(app.buttons[AeroUI.tabGridNewTab], "Expected new tab button in tab grid")

        tapNewTabInTabGrid()

        waitForElement(app.element(AeroUI.newTabTitle), "Expected new tab page after tapping New Tab")
        waitForElement(app.textFields[AeroUI.addressBarTextField], "Expected address field to be focused")
    }

    @MainActor
    func testMenuOpensFromToolbar() throws {
        launchApp()

        openMenu()

        waitForElement(app.staticTexts["Menu"], "Expected menu title to be visible")
        waitForElement(app.element(AeroUI.menuSettings), "Expected Settings action in menu")
    }

    @MainActor
    func testSettingsOpensFromMenu() throws {
        launchApp()

        openMenu()
        waitForElement(app.element(AeroUI.menuSettings), "Expected Settings action in menu").tap()

        waitForElement(app.element(AeroUI.settingsContentBlocker), "Expected content blocker setting")
        XCTAssertTrue(app.staticTexts["Version"].exists)
        XCTAssertTrue(app.staticTexts["WebKit"].exists)
    }

    private func launchApp() {
        app.launch()
    }

    private func openTabGrid(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        revealToolbarIfNeeded()

        let tabsButton = app.buttons[AeroUI.toolbarTabs]
        XCTAssertTrue(
            tabsButton.waitForExistence(timeout: 3),
            "Expected tab grid button before opening tabs",
            file: file,
            line: line
        )

        tabsButton.tap()

        XCTAssertTrue(
            app.buttons[AeroUI.tabGridNewTab].waitForExistence(timeout: 3),
            "Expected tab grid to open",
            file: file,
            line: line
        )
    }

    private func tapNewTabInTabGrid(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let newTabButton = app.buttons[AeroUI.tabGridNewTab]
        XCTAssertTrue(
            newTabButton.waitForExistence(timeout: 3),
            "Expected New Tab button in tab grid",
            file: file,
            line: line
        )

        newTabButton.tap()
    }

    private func openMenu(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        revealToolbarIfNeeded()

        let menuButton = app.buttons[AeroUI.toolbarMenu]
        XCTAssertTrue(
            menuButton.waitForExistence(timeout: 3),
            "Expected menu button before opening menu",
            file: file,
            line: line
        )

        menuButton.tap()

        XCTAssertTrue(
            app.element(AeroUI.menuSettings).waitForExistence(timeout: 3),
            "Expected menu sheet to open",
            file: file,
            line: line
        )
    }

    private func focusAddressBar(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if app.textFields[AeroUI.addressBarTextField].exists {
            return
        }

        let addressDisplay = app.element(AeroUI.addressBarDisplay)
        XCTAssertTrue(
            addressDisplay.waitForExistence(timeout: 3),
            "Expected address display before focusing address bar",
            file: file,
            line: line
        )

        addressDisplay.tap()

        XCTAssertTrue(
            app.textFields[AeroUI.addressBarTextField].waitForExistence(timeout: 3),
            "Expected address text field after tapping address bar",
            file: file,
            line: line
        )
    }

    private func revealToolbarIfNeeded() {
        let compactAddressBar = app.buttons[AeroUI.compactAddressBar]
        if compactAddressBar.exists {
            compactAddressBar.tap()
            let cancelButton = app.buttons[AeroUI.addressBarCancel]
            if cancelButton.waitForExistence(timeout: 1) {
                cancelButton.tap()
            }
            return
        }

        dismissAddressEntryIfNeeded()
    }

    private func dismissAddressEntryIfNeeded() {
        let cancelButton = app.buttons[AeroUI.addressBarCancel]
        if cancelButton.exists {
            cancelButton.tap()
        }
    }

    @discardableResult
    private func waitForElement(
        _ element: XCUIElement,
        _ message: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            message,
            file: file,
            line: line
        )
        return element
    }
}

private enum AeroUI {
    static let addressBarCancel = "browser.addressBar.cancel"
    static let addressBarDisplay = "browser.addressBar.display"
    static let addressBarTextField = "browser.addressBar.textField"
    static let compactAddressBar = "browser.compactAddressBar"

    static let toolbarTabs = "browser.toolbar.tabs"
    static let toolbarMenu = "browser.toolbar.menu"

    static let newTabTitle = "browser.newTab.title"

    static let tabGridNewTab = "browser.tabGrid.newTab"

    static let menuSettings = "browser.menu.settings"

    static let settingsContentBlocker = "browser.settings.contentBlocker"
}

private extension XCUIApplication {
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any)[identifier]
    }
}
