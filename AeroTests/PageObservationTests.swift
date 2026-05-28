import Foundation
import Testing
@testable import Aero

struct PageObservationTests {
    @Test func pageElementTargetConventionIsDeterministicAndPathBased() {
        let path = "html:nth-of-type(1)>body:nth-of-type(1)>main:nth-of-type(1)>button:nth-of-type(2)"
        let otherPath = "html:nth-of-type(1)>body:nth-of-type(1)>main:nth-of-type(1)>button:nth-of-type(3)"

        let id = PageElementTargetConvention.makeTargetID(kind: .button, targetPath: path)

        #expect(PageElementTargetConvention.version == "aero.page-element-target.v1")
        #expect(PageElementTargetConvention.targetPathDescription.contains("tag:nth-of-type"))
        #expect(id == PageElementTargetConvention.makeTargetID(kind: "button", targetPath: path))
        #expect(id.hasPrefix("\(PageElementTargetConvention.targetIDPrefix):button:"))
        #expect(id != PageElementTargetConvention.makeTargetID(kind: .button, targetPath: otherPath))
    }

    @Test func pageObservationDecodingAppliesCaps() throws {
        let longText = String(repeating: "x", count: PageObservationLimits.maxVisibleTextSummaryCharacters + 100)
        let longElementText = String(repeating: "y", count: PageObservationLimits.maxElementTextCharacters + 100)
        let links = (0..<(PageObservationLimits.maxLinks + 5)).map { index in
            PageObservedLink(
                targetID: "target-\(index)",
                targetPath: "html:nth-of-type(1)>body:nth-of-type(1)>a:nth-of-type(\(index + 1))",
                text: longElementText,
                url: "https://example.com/\(index)",
                title: nil,
                ariaLabel: nil
            )
        }
        let payload = TestPageObservationPayload(
            url: "https://example.com",
            title: "Example",
            visibleTextSummary: longText,
            links: links,
            scroll: PageScrollMetrics(scrollY: 12, viewportHeight: 800, contentHeight: 1600, scrollableY: true)
        )
        let json = try payload.jsonString()
        let observedAt = Date(timeIntervalSince1970: 42)

        let observation = try PageObservationService.decodeObservation(from: json, observedAt: observedAt)

        #expect(observation.visibleTextSummary.count == PageObservationLimits.maxVisibleTextSummaryCharacters)
        #expect(observation.links.count == PageObservationLimits.maxLinks)
        #expect(observation.links.first?.text.count == PageObservationLimits.maxElementTextCharacters)
        #expect(observation.scroll.scrollY == 12)
        #expect(observation.scroll.scrollableY)
        #expect(observation.observedAt == observedAt)
    }

    @Test func pageObservationExposesActionTargetsForInputsAndForms() throws {
        let inputPath = "html:nth-of-type(1)>body:nth-of-type(1)>form:nth-of-type(1)>input:nth-of-type(1)"
        let inputID = PageElementTargetConvention.makeTargetID(kind: .input, targetPath: inputPath)
        let formPath = "html:nth-of-type(1)>body:nth-of-type(1)>form:nth-of-type(1)"
        let formID = PageElementTargetConvention.makeTargetID(kind: .form, targetPath: formPath)
        let payload = TestPageObservationPayload(
            url: "https://example.com/search",
            title: "Search",
            visibleTextSummary: "Search the site",
            inputs: [
                PageObservedInput(
                    targetID: inputID,
                    targetPath: inputPath,
                    label: "Search",
                    type: "search",
                    name: "q",
                    placeholder: "Search",
                    value: "",
                    isRequired: false,
                    isDisabled: false,
                    isSearchField: true
                ),
            ],
            forms: [
                PageObservedForm(
                    targetID: formID,
                    targetPath: formPath,
                    label: "Site search",
                    action: "https://example.com/search",
                    method: "GET",
                    fieldTargetIDs: [inputID],
                    searchFieldTargetIDs: [inputID]
                ),
            ],
            elements: [
                PageObservedElement(
                    targetID: inputID,
                    targetPath: inputPath,
                    kind: .input,
                    label: "Search",
                    text: nil,
                    isEnabled: true
                ),
            ],
            scroll: PageScrollMetrics()
        )

        let observation = try PageObservationService.decodeObservation(from: try payload.jsonString())

        #expect(observation.inputs.first?.targetID == inputID)
        #expect(observation.inputs.first?.targetPath == inputPath)
        #expect(observation.inputs.first?.isSearchField == true)
        #expect(observation.forms.first?.searchFieldTargetIDs == [inputID])
        #expect(observation.elements.first?.targetPath == inputPath)
    }
}

private struct TestPageObservationPayload: Encodable {
    var url: String?
    var title: String?
    var visibleTextSummary: String?
    var links: [PageObservedLink]?
    var buttons: [PageObservedButton]?
    var inputs: [PageObservedInput]?
    var forms: [PageObservedForm]?
    var scroll: PageScrollMetrics?
    var elements: [PageObservedElement]?

    init(
        url: String? = nil,
        title: String? = nil,
        visibleTextSummary: String? = nil,
        links: [PageObservedLink]? = nil,
        buttons: [PageObservedButton]? = nil,
        inputs: [PageObservedInput]? = nil,
        forms: [PageObservedForm]? = nil,
        scroll: PageScrollMetrics? = nil,
        elements: [PageObservedElement]? = nil
    ) {
        self.url = url
        self.title = title
        self.visibleTextSummary = visibleTextSummary
        self.links = links
        self.buttons = buttons
        self.inputs = inputs
        self.forms = forms
        self.scroll = scroll
        self.elements = elements
    }

    func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(decoding: data, as: UTF8.self)
    }
}
