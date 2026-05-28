import Foundation

extension BrowserViewModel {
    @MainActor
    var agentRunEngine: AgentRunEngine {
        if let agentRunEngineStorage {
            return agentRunEngineStorage
        }

        let browserTools = LiveAgentBrowserTools(target: self)
        let engine = AgentRunEngine(
            toolLoopRunner: LiveAgentToolLoopRunner(searchEngine: searchEngine),
            browserTools: browserTools
        )
        browserTools.onApprovalRequested = { [weak engine] request in
            engine?.recordApprovalRequested(request)
        }
        browserTools.onApprovalResolved = { [weak engine] request, decision in
            engine?.recordApprovalResolved(request, decision)
        }

        agentBrowserToolsStorage = browserTools
        agentRunEngineStorage = engine
        return engine
    }

    @MainActor
    func startAgentRun(prompt: String) {
        agentBrowserToolsStorage?.cancelPendingApprovals()
        _ = agentRunEngine.start(prompt: prompt)
    }

    @MainActor
    func stopAgentRun() {
        agentRunEngine.stop()
        agentBrowserToolsStorage?.cancelPendingApprovals()
    }

    @MainActor
    func clearAgentRunSession() {
        agentRunEngine.clear()
        agentBrowserToolsStorage?.cancelPendingApprovals()
    }

    @MainActor
    func approvePendingAgentAction() {
        resolvePendingAgentApproval(.approved)
    }

    @MainActor
    func denyPendingAgentAction() {
        resolvePendingAgentApproval(.denied)
    }

    @MainActor
    private func resolvePendingAgentApproval(_ decision: AgentApprovalDecision) {
        guard let approval = agentRunEngine.session.pendingApproval else { return }

        agentBrowserToolsStorage?.resolveApproval(id: approval.id, decision: decision)
    }
}
