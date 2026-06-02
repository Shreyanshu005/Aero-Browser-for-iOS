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
        
        // --- Step 1: Navigate to starting point (single visible step) ---
        let navStep = await startStep(
            title: "Navigating",
            detail: Self.navigationLabel(for: resolution),
            eventHandler: eventHandler
        )
        
        if resolution.kind == .webSearch {
            _ = try await browserTools.openURL(resolution.url)
        } else if resolution.kind == .directURL && request.currentURL != resolution.url {
            _ = try await browserTools.openURL(resolution.url)
        }
        
        await updateStep(navStep, status: .completed, detail: Self.navigationLabel(for: resolution), eventHandler: eventHandler)
        
        var history: [String] = []
        let maxSteps = 15
        var finalResult = "Task completed."
        
        for step in 0..<maxSteps {
            try Task.checkCancellation()
            
            // ── Observe page (silent — no step emitted) ──
            let thinkStep = await startStep(
                title: Self.thinkingPhrase(for: step),
                detail: "Scanning the page…",
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
                await updateStep(thinkStep, status: .failed, detail: "Page didn't respond.", eventHandler: eventHandler)
                throw AgentNetworkError.apiError("Failed to observe page after 20 seconds. Error: \(errorDesc)")
            }
            
            // ── Ask LLM (update the same step — no new row) ──
            await updateStep(thinkStep, status: .running, detail: "Deciding next move…", eventHandler: eventHandler)
            
            var responseText: String = ""
            var parsed: [String: Any]?
            var actionType: String?
            var jsonRetries = 0
            
            while jsonRetries <= Self.maxJSONRetries {
                do {
                    responseText = try await client.nextAction(task: request.prompt, observation: validObservation, history: history)
                } catch let error as AgentNetworkError where error.isRateLimited {
                    await updateStep(thinkStep, status: .failed, detail: "Rate limited — cooling down…", eventHandler: eventHandler)
                    throw error
                } catch {
                    await updateStep(thinkStep, status: .failed, detail: "LLM error: \(error.localizedDescription)", eventHandler: eventHandler)
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
                }
            }
            
            guard let parsed, let actionType else {
                await updateStep(thinkStep, status: .failed, detail: "Couldn't parse a valid action.", eventHandler: eventHandler)
                throw AgentNetworkError.invalidJSON(rawResponse: responseText)
            }
            
            history.append("Step \(step): \(responseText)")
            if history.count > Self.maxHistoryTurns {
                history = Array(history.suffix(Self.maxHistoryTurns))
            }
            
            // ── Done? ──
            if actionType == "done" {
                finalResult = parsed["result"] as? String ?? "Task completed."
                await updateStep(thinkStep, status: .completed, detail: "Finished!", eventHandler: eventHandler)
                break
            }
            
            // ── Execute action (update the SAME step with a cool label) ──
            let actionLabel = Self.actionLabel(actionType: actionType, parsed: parsed)
            await updateStep(thinkStep, status: .running, detail: actionLabel, eventHandler: eventHandler)
            
            do {
                var toolResult: AgentBrowserToolResult?
                switch actionType {
                case "click":
                    if let id = parsed["elementID"] as? String {
                        toolResult = try await browserTools.click(elementID: id)
                    }
                case "type":
                    if let text = parsed["text"] as? String {
                        let id = parsed["elementID"] as? String
                        toolResult = try await browserTools.type(text, into: id)
                        
                        let shouldSubmit: Bool = {
                            if let b = parsed["submit"] as? Bool { return b }
                            if let s = parsed["submit"] as? String { return s.lowercased() == "true" }
                            return false
                        }()
                        
                        if toolResult?.actionResult?.status != .failed, shouldSubmit {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            toolResult = try await browserTools.pressKey(.enter)
                        }
                    }
                case "navigate":
                    if let urlStr = parsed["url"] as? String, let url = URL(string: urlStr) {
                        toolResult = try await browserTools.openURL(url)
                    }
                case "scroll":
                    let dirStr = parsed["direction"] as? String ?? "down"
                    let dir: AgentScrollDirection = dirStr == "up" ? .up : .down
                    toolResult = try await browserTools.scroll(dir)
                case "wait":
                    let secs = parsed["seconds"] as? Double ?? 2.0
                    toolResult = try await browserTools.wait(seconds: secs)
                default:
                    break
                }
                
                if let result = toolResult, result.actionResult?.status == .failed {
                    struct ToolFailure: Error, LocalizedError {
                        var errorDescription: String?
                    }
                    throw ToolFailure(errorDescription: result.summary)
                }
                
                await updateStep(thinkStep, status: .completed, detail: actionLabel, eventHandler: eventHandler)
            } catch {
                await updateStep(thinkStep, status: .failed, detail: "Failed: \(actionLabel)", eventHandler: eventHandler)
                history.append("Action \(actionType) failed: \(error.localizedDescription)")
            }
            
            // Wait for page to settle (1.5s spaces out API calls for rate limits)
            _ = try await browserTools.wait(seconds: 1.5)
        }
        
        return AgentToolLoopResult(finalAnswer: finalResult)
    }
    
    // MARK: - Cool Labels
    
    /// Rotating "thinking" phrases so the UI feels alive.
    private static func thinkingPhrase(for step: Int) -> String {
        let phrases = [
            "Analyzing",
            "Exploring",
            "Inspecting",
            "Processing",
            "Evaluating",
            "Scanning",
            "Investigating",
            "Reasoning",
            "Interpreting",
            "Assessing",
            "Examining",
            "Mapping out",
            "Decoding",
            "Reading",
            "Synthesizing",
        ]
        return phrases[step % phrases.count]
    }
    
    /// Human-friendly action descriptions.
    private static func actionLabel(actionType: String, parsed: [String: Any]) -> String {
        switch actionType {
        case "click":
            let id = parsed["elementID"] as? String ?? ""
            return "Tapping element \(id)"
        case "type":
            let text = parsed["text"] as? String ?? ""
            let preview = text.count > 30 ? String(text.prefix(30)) + "…" : text
            return "Typing \"\(preview)\""
        case "navigate":
            if let urlStr = parsed["url"] as? String,
               let host = URL(string: urlStr)?.host {
                return "Opening \(host)"
            }
            return "Navigating…"
        case "scroll":
            let dir = parsed["direction"] as? String ?? "down"
            return "Scrolling \(dir)"
        case "wait":
            return "Waiting for page…"
        default:
            return actionType.capitalized
        }
    }
    
    /// Navigation label for the initial step.
    private static func navigationLabel(for resolution: AgentSiteResolution) -> String {
        if let host = resolution.url.host {
            return "Opening \(host)"
        }
        return "Opening page…"
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
