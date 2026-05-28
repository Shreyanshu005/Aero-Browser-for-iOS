import Foundation

@MainActor
protocol AgentBrowserTooling {
    func observePage() async throws -> AgentPageObservation
    func openURL(_ url: URL) async throws -> AgentBrowserToolResult
    func click(elementID: String) async throws -> AgentBrowserToolResult
    func type(_ text: String, into elementID: String?) async throws -> AgentBrowserToolResult
    func pressKey(_ key: AgentBrowserKey) async throws -> AgentBrowserToolResult
    func scroll(_ direction: AgentScrollDirection) async throws -> AgentBrowserToolResult
    func wait(seconds: TimeInterval) async throws -> AgentBrowserToolResult
    func extractData(_ request: AgentDataExtractionRequest) async throws -> AgentBrowserToolResult
    func requestApproval(_ request: AgentApprovalRequest) async -> AgentApprovalDecision
}
