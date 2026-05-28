import Foundation
import Testing
@testable import Aero

struct AgentRunEngineTests {

    @Test
    @MainActor
    func startCompletesWithFinalAnswer() async {
        let runner = MockToolLoopRunner { request, _, emit in
            #expect(request.prompt == "Summarize this page")

            let step = AgentRunStep(
                kind: .browserTool,
                status: .running,
                title: "Observe page",
                detail: "Reading visible page content."
            )
            await emit(.stepStarted(step))
            await emit(.stepUpdated(id: step.id, status: .completed, title: nil, detail: "Page observed."))

            return AgentToolLoopResult(finalAnswer: "This page is a browser project.")
        }
        let engine = AgentRunEngine(toolLoopRunner: runner, browserTools: MockBrowserTools())

        let runID = engine.start(prompt: "  Summarize this page  ")
        await settleAgentRunTask()

        #expect(runID != nil)
        #expect(engine.session.status == .completed)
        #expect(engine.session.prompt == "Summarize this page")
        #expect(engine.session.finalAnswer == "This page is a browser project.")
        #expect(engine.session.steps.contains { $0.kind == .finalAnswer && $0.status == .completed })
        #expect(engine.session.steps.contains { $0.title == "Observe page" && $0.status == .completed })
    }

    @Test
    @MainActor
    func startCapturesRunnerError() async {
        let runner = MockToolLoopRunner { _, _, _ in
            throw MockRunError.failed
        }
        let engine = AgentRunEngine(toolLoopRunner: runner, browserTools: MockBrowserTools())

        _ = engine.start(prompt: "Find prices")
        await settleAgentRunTask()

        #expect(engine.session.status == .failed)
        #expect(engine.session.error?.message == "Tool loop failed")
        #expect(engine.session.finalAnswer == nil)
        #expect(engine.session.steps.contains { $0.kind == .error && $0.status == .failed })
    }

    @Test
    @MainActor
    func approvalRequestMovesSessionToWaitingState() async {
        let approval = AgentApprovalRequest(
            kind: .pageAccess,
            title: "Allow page access",
            detail: "Read the visible page before continuing."
        )
        let runner = MockToolLoopRunner { _, _, emit in
            await emit(.approvalRequested(approval))
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return AgentToolLoopResult(finalAnswer: "Done")
        }
        let engine = AgentRunEngine(toolLoopRunner: runner, browserTools: MockBrowserTools())

        _ = engine.start(prompt: "Read page")
        await settleAgentRunTask()

        #expect(engine.session.status == .waitingForApproval)
        #expect(engine.session.pendingApproval == approval)
        #expect(engine.session.steps.contains { $0.kind == .approval && $0.status == .waitingForApproval })

        engine.stop()
    }

    @Test
    @MainActor
    func stopCancelsActiveRunAndMarksStopped() {
        let runner = MockToolLoopRunner { _, _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return AgentToolLoopResult(finalAnswer: "Done")
        }
        let engine = AgentRunEngine(toolLoopRunner: runner, browserTools: MockBrowserTools())

        _ = engine.start(prompt: "Keep working")
        engine.stop()

        #expect(engine.session.status == .stopped)
        #expect(engine.session.endedAt != nil)
        #expect(engine.session.pendingApproval == nil)
        #expect(engine.session.steps.contains { $0.status == .stopped })
    }

    @Test
    @MainActor
    func clearResetsSessionAndCancelsActiveRun() {
        let runner = MockToolLoopRunner { _, _, _ in
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return AgentToolLoopResult(finalAnswer: "Done")
        }
        let engine = AgentRunEngine(toolLoopRunner: runner, browserTools: MockBrowserTools())

        _ = engine.start(prompt: "Temporary task")
        engine.clear()

        #expect(engine.session.status == .idle)
        #expect(engine.session.prompt.isEmpty)
        #expect(engine.session.steps.isEmpty)
        #expect(engine.session.finalAnswer == nil)
        #expect(engine.session.error == nil)
    }
}

private struct MockToolLoopRunner: AgentToolLoopRunning {
    var handler: (
        AgentToolLoopRequest,
        AgentBrowserTooling,
        (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult

    func run(
        request: AgentToolLoopRequest,
        browserTools: AgentBrowserTooling,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult {
        try await handler(request, browserTools, eventHandler)
    }
}

private struct MockBrowserTools: AgentBrowserTooling {
    func observePage() async throws -> AgentPageObservation {
        AgentPageObservation(title: "Example", visibleText: "Example page")
    }

    func openURL(_ url: URL) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Opened \(url.absoluteString)")
    }

    func click(elementID: String) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Clicked \(elementID)")
    }

    func type(_ text: String, into elementID: String?) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Typed text")
    }

    func pressKey(_ key: AgentBrowserKey) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Pressed \(key.rawValue)")
    }

    func scroll(_ direction: AgentScrollDirection) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Scrolled \(direction.rawValue)")
    }

    func wait(seconds: TimeInterval) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: "Waited \(seconds) seconds")
    }

    func extractData(_ request: AgentDataExtractionRequest) async throws -> AgentBrowserToolResult {
        AgentBrowserToolResult(summary: request.prompt)
    }

    func requestApproval(_ request: AgentApprovalRequest) async -> AgentApprovalDecision {
        .approved
    }
}

private enum MockRunError: LocalizedError {
    case failed

    var errorDescription: String? {
        "Tool loop failed"
    }
}

private func settleAgentRunTask() async {
    for _ in 0..<20 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}
