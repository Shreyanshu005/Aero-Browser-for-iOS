import Foundation

struct AutonomousToolLoopRunner: AgentToolLoopRunning {
    let settingsStore: BrowserSettingsStoring
    let resolver = AgentSiteResolver()
    
    /// Maximum conversation history turns to keep (rolling window).
    private static let maxHistoryTurns = 6
    /// Maximum retries when the LLM returns unparseable JSON.
    private static let maxJSONRetries = 2
    
    func run(
        request: AgentToolLoopRequest,
        browserTools: AgentBrowserTooling,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult {
        try Task.checkCancellation()
        
        let resolution = resolver.resolve(request.prompt, currentURL: request.currentURL)
        
        let config = settingsStore.loadAgentProviderConfiguration()
        let descriptor = try AgentProviderResolver().descriptor(for: config)
        let client = AgentNetworkClient(descriptor: descriptor)
        
        let resolveStep = await startStep(
            title: "Plan autonomous run",
            detail: "Starting task: \\(request.prompt)",
            eventHandler: eventHandler
        )
        
        if resolution.kind == .webSearch {
            // Need to navigate to web search first
            _ = try await browserTools.openURL(resolution.url)
        } else if resolution.kind == .directURL && request.currentURL != resolution.url {
            _ = try await browserTools.openURL(resolution.url)
        }
        
        await updateStep(
            resolveStep,
            status: .completed,
            detail: "Navigated to starting point: \\(resolution.url.absoluteString)",
            eventHandler: eventHandler
        )
        
        var history: [String] = []
        let maxSteps = 15
        var finalResult = "Task completed."
        
        for step in 0..<maxSteps {
            try Task.checkCancellation()
            
            let observeStep = await startStep(
                title: "Observe page",
                detail: "Reading accessibility tree...",
                eventHandler: eventHandler
            )
            
            var observation: AgentPageObservation?
            var lastError: Error?
            for _ in 0..<20 {
                do {
                    observation = try await browserTools.observePage()
                    break
                } catch {
                    lastError = error
                    _ = try await browserTools.wait(seconds: 1.0)
                }
            }
            
            guard let validObservation = observation else {
                let errorDesc = lastError?.localizedDescription ?? "unknown"
                await updateStep(observeStep, status: .failed, detail: "Page not loaded or WebView missing. Last error: \\(errorDesc)", eventHandler: eventHandler)
                throw AgentNetworkError.apiError("Failed to observe page after 20 seconds. Error: \\(errorDesc)")
            }
            
            await updateStep(
                observeStep,
                status: .completed,
                detail: "Observed \\(validObservation.elements.count) elements.",
                eventHandler: eventHandler
            )
            
            let planStep = await startStep(
                title: "Planning next action",
                detail: "Asking LLM...",
                eventHandler: eventHandler
            )
            
            // --- Improvement #5: JSON parse auto-retry ---
            var responseText: String = ""
            var parsed: [String: Any]?
            var actionType: String?
            var jsonRetries = 0
            
            while jsonRetries <= Self.maxJSONRetries {
                do {
                    // --- Improvement #2: 429 errors are retried inside nextAction ---
                    responseText = try await client.nextAction(task: request.prompt, observation: validObservation, history: history)
                } catch let error as AgentNetworkError where error.isRateLimited {
                    await updateStep(
                        planStep,
                        status: .failed,
                        detail: "Rate limited by API. Waiting before retry...",
                        eventHandler: eventHandler
                    )
                    throw error
                } catch {
                    await updateStep(
                        planStep,
                        status: .failed,
                        detail: "LLM error: \\(error.localizedDescription)",
                        eventHandler: eventHandler
                    )
                    throw error
                }
                
                if let jsonData = responseText.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let action = obj["action"] as? String {
                    parsed = obj
                    actionType = action
                    break
                }
                
                jsonRetries += 1
                if jsonRetries <= Self.maxJSONRetries {
                    history.append("System: Your last response was not valid JSON. Please reply with ONLY a JSON object.")
                    await updateStep(
                        planStep,
                        status: .running,
                        detail: "Invalid JSON from LLM, retrying (\\(jsonRetries)/\\(Self.maxJSONRetries))...",
                        eventHandler: eventHandler
                    )
                }
            }
            
            guard let parsed, let actionType else {
                await updateStep(
                    planStep,
                    status: .failed,
                    detail: "Invalid LLM JSON after \\(Self.maxJSONRetries) retries: \\(responseText.prefix(200))",
                    eventHandler: eventHandler
                )
                throw AgentNetworkError.invalidJSON(rawResponse: responseText)
            }
            
            history.append("Step \\(step): \\(responseText)")
            // --- Improvement #3: Trim history to rolling window ---
            if history.count > Self.maxHistoryTurns {
                history = Array(history.suffix(Self.maxHistoryTurns))
            }
            
            await updateStep(
                planStep,
                status: .completed,
                detail: "Decided to \\(actionType)",
                eventHandler: eventHandler
            )
            
            if actionType == "done" {
                finalResult = parsed["result"] as? String ?? "Task completed."
                break
            }
            
            let executeStep = await startStep(
                title: "Execute action",
                detail: "Executing: \\(actionType)",
                eventHandler: eventHandler
            )
            
            do {
                switch actionType {
                case "click":
                    if let id = parsed["elementID"] as? String {
                        _ = try await browserTools.click(elementID: id)
                    }
                case "type":
                    if let text = parsed["text"] as? String {
                        let id = parsed["elementID"] as? String
                        _ = try await browserTools.type(text, into: id)
                        // Auto-press enter if needed, or LLM can call click
                        if parsed["submit"] as? Bool == true {
                            _ = try await browserTools.pressKey(.enter)
                        }
                    }
                case "navigate":
                    if let urlStr = parsed["url"] as? String, let url = URL(string: urlStr) {
                        _ = try await browserTools.openURL(url)
                    }
                case "scroll":
                    let dirStr = parsed["direction"] as? String ?? "down"
                    let dir: AgentScrollDirection = dirStr == "up" ? .up : .down
                    _ = try await browserTools.scroll(dir)
                case "wait":
                    let secs = parsed["seconds"] as? Double ?? 2.0
                    _ = try await browserTools.wait(seconds: secs)
                default:
                    break
                }
                
                await updateStep(
                    executeStep,
                    status: .completed,
                    detail: "Executed \\(actionType) successfully.",
                    eventHandler: eventHandler
                )
            } catch {
                await updateStep(
                    executeStep,
                    status: .failed,
                    detail: "Action failed: \\(error.localizedDescription)",
                    eventHandler: eventHandler
                )
                history.append("Action \\(actionType) failed: \\(error.localizedDescription)")
            }
            
            // Wait for page to settle after action (0.8s is enough for most re-renders)
            _ = try await browserTools.wait(seconds: 0.8)
        }
        
        return AgentToolLoopResult(finalAnswer: finalResult)
    }
    
    private func startStep(
        title: String,
        detail: String,
        kind: AgentRunStepKind = .browserTool,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async -> AgentRunStep {
        let step = AgentRunStep(
            kind: kind,
            status: .running,
            title: title,
            detail: detail
        )
        await eventHandler(.stepStarted(step))
        return step
    }

    private func updateStep(
        _ step: AgentRunStep,
        status: AgentRunStepStatus,
        detail: String?,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async {
        await eventHandler(
            .stepUpdated(id: step.id, status: status, title: nil, detail: detail)
        )
    }
}
