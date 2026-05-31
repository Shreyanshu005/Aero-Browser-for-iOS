import Foundation

extension BrowserViewModel {
    @MainActor
    var agentRunEngine: AgentRunEngine {
        if let agentRunEngineStorage {
            return agentRunEngineStorage
        }

        let browserTools = LiveAgentBrowserTools(target: self)
        let config = settingsStore.loadAgentProviderConfiguration()
        let descriptor: AgentResolvedProviderDescriptor
        do {
            descriptor = try AgentProviderResolver().descriptor(for: config)
        } catch {
            // Fallback to a default if it fails (e.g. missing API key)
            descriptor = AgentResolvedProviderDescriptor(providerID: .groq, model: "llama-3.3-70b-versatile", modelString: "groq/llama-3.3-70b-versatile", apiKey: nil, baseURL: "https://api.groq.com/openai/v1")
        }
        
        let client = AgentNetworkClient(descriptor: descriptor)
        let toolLoopRunner = AutonomousToolLoopRunner(client: client)
        
        let engine = AgentRunEngine(
            toolLoopRunner: toolLoopRunner,
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
        _ = agentRunEngine.start(prompt: prompt, currentURL: activeTab?.url)
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
