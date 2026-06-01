import Foundation

enum AgentNetworkError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    case rateLimited(retryAfterSeconds: Int?)
    case invalidJSON(rawResponse: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .apiError(let msg): return "API Error: \(msg)"
        case .rateLimited(let seconds):
            if let s = seconds {
                return "Rate limited. Retry after \(s)s."
            }
            return "Rate limited by the API."
        case .invalidJSON(let raw):
            return "LLM returned invalid JSON: \(raw.prefix(200))"
        }
    }
    
    var isRateLimited: Bool {
        if case .rateLimited = self { return true }
        return false
    }
}

struct AgentNetworkClient {
    let descriptor: AgentResolvedProviderDescriptor
    
    /// Maximum number of history turns to send to the LLM.
    /// Keeps token usage manageable and avoids exceeding context windows.
    private static let maxHistoryTurns = 6
    
    /// Maximum retries when the API returns 429 (rate limited).
    private static let maxRateLimitRetries = 2
    
    /// Seconds to wait between rate-limit retries.
    private static let rateLimitBackoffSeconds: [UInt64] = [5, 15]
    
    func nextAction(task: String, observation: AgentPageObservation, history: [String]) async throws -> String {
        let cappedElements = Self.trimElements(observation.elements, limit: 40)
        
        let elements = cappedElements
            .map { "[\($0.id)] \($0.role): \($0.label) \($0.text)" }
            .joined(separator: "\n")
        
        let trimmedHistory = Array(history.suffix(Self.maxHistoryTurns))
        
        let pageText = String(observation.visibleText.prefix(6000))
            
        let prompt = """
        TASK: \(task)

        CURRENT PAGE STATE:
        URL: \(observation.url?.absoluteString ?? "Unknown")
        Title: \(observation.title)

        VISIBLE PAGE TEXT:
        \(pageText)

        INTERACTIVE ELEMENTS (id, type, label):
        \(elements.isEmpty ? "(no interactive elements found — try scrolling)" : elements)

        ACTIONS ALREADY TAKEN:
        \(trimmedHistory.isEmpty ? "(none yet)" : trimmedHistory.joined(separator: "\n"))

        RULES:
        1. Return exactly ONE JSON object. No markdown, no explanation.
        2. Available actions:
           {"action":"click","elementID":"<id>"} — click a button or link by its ID
           {"action":"type","elementID":"<id>","text":"<text>"} — type text into an input field
           {"action":"type","elementID":"<id>","text":"<text>","submit":true} — type and press Enter
           {"action":"scroll","direction":"down"} — scroll to reveal more content (or "up")
           {"action":"navigate","url":"<full_url>"} — go to a specific URL
           {"action":"wait","seconds":2} — wait for page to load
           {"action":"done","result":"<your detailed answer>"} — finish the task
        3. When using "done", the "result" field MUST contain the ACTUAL answer to the user's question using information you found on the page. Include specific data, names, numbers, prices, text — whatever the user asked for. NEVER just say "Task completed" — that is useless.
        4. If the page has the information the user needs, extract it from the VISIBLE PAGE TEXT above and return it with "done".
        5. If you need more information, scroll down, click on relevant links, or navigate to find it.
        6. If you see a search box and need to search, type the query and submit.
        7. Do NOT repeat the same action. Check your history. If an action didn't work, try something different.
        8. If stuck after several attempts, use "done" and explain what you found and what went wrong.
        """
        
        // --- Improvement #2: 429 rate-limit backoff ---
        var lastError: Error?
        for attempt in 0...Self.maxRateLimitRetries {
            do {
                if descriptor.providerID == .gemini {
                    return try await generateGemini(prompt: prompt)
                } else {
                    return try await generateOpenAI(prompt: prompt)
                }
            } catch let error as AgentNetworkError where error.isRateLimited {
                lastError = error
                if attempt < Self.maxRateLimitRetries {
                    let backoff = Self.rateLimitBackoffSeconds[min(attempt, Self.rateLimitBackoffSeconds.count - 1)]
                    try await Task.sleep(nanoseconds: backoff * 1_000_000_000)
                    continue
                }
            }
        }
        
        throw lastError ?? AgentNetworkError.apiError("Rate limited after retries.")
    }
    
    /// Trims the element list to stay within the LLM's token budget.
    /// Prioritizes: inputs/forms first (most actionable), then buttons, then links.
    /// Elements near the top of the page are preferred.
    private static func trimElements(_ elements: [AgentPageElement], limit: Int) -> [AgentPageElement] {
        guard elements.count > limit else { return elements }
        
        var inputs: [AgentPageElement] = []
        var buttons: [AgentPageElement] = []
        var links: [AgentPageElement] = []
        var others: [AgentPageElement] = []
        
        for el in elements {
            switch el.role.lowercased() {
            case "input", "form", "textarea", "select":
                inputs.append(el)
            case "button":
                buttons.append(el)
            case "link":
                links.append(el)
            default:
                others.append(el)
            }
        }
        
        var result: [AgentPageElement] = []
        // Always include all inputs (users need them to type)
        result.append(contentsOf: inputs)
        
        let remaining = limit - result.count
        if remaining > 0 {
            let buttonSlice = Array(buttons.prefix(min(buttons.count, remaining / 2 + 1)))
            result.append(contentsOf: buttonSlice)
        }
        
        let remaining2 = limit - result.count
        if remaining2 > 0 {
            result.append(contentsOf: links.prefix(remaining2))
        }
        
        let remaining3 = limit - result.count
        if remaining3 > 0 {
            result.append(contentsOf: others.prefix(remaining3))
        }
        
        return Array(result.prefix(limit))
    }
    
    private func generateGemini(prompt: String) async throws -> String {
        let model = descriptor.model.isEmpty ? "gemini-2.0-flash" : descriptor.model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(descriptor.apiKey ?? "")"
        guard let url = URL(string: urlString) else { throw AgentNetworkError.invalidURL }
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "maxOutputTokens": 1024,
                "temperature": 0.1
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for rate limiting
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw AgentNetworkError.rateLimited(retryAfterSeconds: retryAfter)
        }
        
        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = errorJson["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw AgentNetworkError.apiError(message)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        let text = parts?.first?["text"] as? String ?? ""
        return cleanResponse(text)
    }
    
    private func generateOpenAI(prompt: String) async throws -> String {
        var baseURLString = descriptor.baseURL ?? "https://api.openai.com/v1"
        if descriptor.providerID == .groq && descriptor.baseURL == nil {
            baseURLString = "https://api.groq.com/openai/v1"
        }
        if descriptor.providerID == .openRouter && descriptor.baseURL == nil {
            baseURLString = "https://openrouter.ai/api/v1"
        }
        
        if baseURLString.hasSuffix("/") { baseURLString.removeLast() }
        
        guard let url = URL(string: "\(baseURLString)/chat/completions") else { throw AgentNetworkError.invalidURL }
        
        let systemMessage = """
        You are an autonomous browser agent controlling a real iOS browser. You MUST return only a valid JSON object — no explanations, no markdown.
        CRITICAL: When you use {"action":"done","result":"..."}, the result MUST contain the ACTUAL information the user asked for — real data extracted from the page. NEVER return generic text like "Task completed" or "Done". Include specific facts, numbers, text, or a clear explanation of what you found.
        """
        let body: [String: Any] = [
            "model": descriptor.model,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 1024,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = descriptor.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // --- Improvement #2: Detect 429 rate limits ---
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw AgentNetworkError.rateLimited(retryAfterSeconds: retryAfter)
        }
        
        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = errorJson["error"] as? [String: Any],
           let message = errorObj["message"] as? String {
            throw AgentNetworkError.apiError(message)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        let text = message?["content"] as? String ?? ""
        return cleanResponse(text)
    }
    
    private func cleanResponse(_ text: String) -> String {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") {
            clean = clean.replacingOccurrences(of: "```json", with: "")
        }
        if clean.hasPrefix("```") {
            clean = String(clean.dropFirst(3))
        }
        if clean.hasSuffix("```") {
            clean = String(clean.dropLast(3))
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
