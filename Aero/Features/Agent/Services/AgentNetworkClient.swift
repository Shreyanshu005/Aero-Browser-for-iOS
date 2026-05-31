import Foundation

enum AgentNetworkError: Error, LocalizedError {
    case invalidURL
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .apiError(let msg): return "API Error: \(msg)"
        }
    }
}

struct AgentNetworkClient {
    let descriptor: AgentResolvedProviderDescriptor
    
    func nextAction(task: String, observation: AgentPageObservation, history: [String]) async throws -> String {
        let elements = observation.elements
            .map { "[\($0.id)] \($0.role): \($0.label) \($0.text)" }
            .joined(separator: "\n")
            
        let prompt = """
        You are an autonomous browser agent. Your task is: \(task)
        
        Current page:
        URL: \(observation.url?.absoluteString ?? "Unknown")
        Title: \(observation.title)
        Text: \(String(observation.visibleText.prefix(4000)))
        
        Interactive elements:
        \(elements)
        
        History of actions taken:
        \(history.joined(separator: "\n"))
        
        You must decide the next single action to take.
        Reply ONLY with one valid JSON object and nothing else. No markdown wrapping.
        {"action":"click","elementID":"ID"}
        {"action":"type","elementID":"ID","text":"..."}
        {"action":"navigate","url":"https://..."}
        {"action":"scroll","direction":"down"} // or "up"
        {"action":"wait","seconds":2}
        {"action":"done","result":"..."}
        """
        
        if descriptor.providerID == .gemini {
            return try await generateGemini(prompt: prompt)
        } else {
            return try await generateOpenAI(prompt: prompt)
        }
    }
    
    private func generateGemini(prompt: String) async throws -> String {
        let model = descriptor.model.isEmpty ? "gemini-2.0-flash" : descriptor.model
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(descriptor.apiKey ?? "")"
        guard let url = URL(string: urlString) else { throw AgentNetworkError.invalidURL }
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
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
        
        let body: [String: Any] = [
            "model": descriptor.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.0
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = descriptor.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
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
