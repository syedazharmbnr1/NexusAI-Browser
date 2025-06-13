#!/bin/bash
# NexusAI Browser - Revolutionary Agentic Browser Installer
# The world's most advanced AI-powered browser

set -e

echo "🚀 NexusAI Browser - Revolutionary Agentic Browser"
echo "================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This installer is for macOS only${NC}"
    exit 1
fi

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo "Please complete the Xcode installation and run this script again."
    exit 1
fi

# Create project directory
PROJECT_DIR="$HOME/NexusAIBrowser"
echo "Creating project directory at $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create the main application file
echo "Building revolutionary agentic browser..."
cat > NexusAIBrowser.swift << 'EOAPP'

import SwiftUI
import WebKit
import Combine
import Vision
import NaturalLanguage
import CoreML
import PDFKit

// MARK: - Lucid Glass UI Helpers (Liquid Glass style from iOS 26)
/// Provides a blurred glass background and subtle white stroke.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
    }
}
extension View {
    /// Apply Apple‑style translucent background
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

/// Makes any overlay draggable like a floating window.
struct DraggableWindow: ViewModifier {
    @State private var offset: CGSize = .zero
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { offset = $0.translation }
            )
    }
}
extension View {
    /// Allow the view to be moved around by dragging.
    func draggableWindow() -> some View {
        modifier(DraggableWindow())
    }
}

// MARK: - Helper functions for automation‑action visuals
func iconForActionType(_ type: SmartAgent.AutomationAction.ActionType) -> String {
    switch type {
    case .click:   return "cursorarrow.click"
    case .type:    return "keyboard"
    case .select:  return "list.bullet"
    case .navigate:return "arrow.right.circle"
    case .scroll:  return "arrow.up.and.down"
    case .wait:    return "clock"
    case .extract: return "doc.text.magnifyingglass"
    case .verify:  return "checkmark.circle"
    }
}

func colorForActionType(_ type: SmartAgent.AutomationAction.ActionType) -> Color {
    switch type {
    case .click:   return .blue
    case .type:    return .green
    case .select:  return .orange
    case .navigate:return .purple
    case .scroll:  return .pink
    case .wait:    return .yellow
    case .extract: return .cyan
    case .verify:  return .mint
    }
}

// MARK: - Simple Markdown → AttributedString helper
extension String {
    /// Converts markdown syntax to an AttributedString for rich display.
    func asMarkdownAttributed(fontSize: CGFloat = 12) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: self,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return attributed
        } else {
            return AttributedString(self)
        }
    }
}

// MARK: - AI Agent Types
enum AgentCapability {
    case research
    case formFilling
    case contentExtraction
    case taskAutomation
    case smartNavigation
    case contentCreation
    case dataAnalysis
    case codeGeneration
}

// MARK: - Gemini API Service
class GeminiAPIService: ObservableObject {
    @Published var isProcessing = false
    
    private var apiKey: String = "YOUR_GEMINI_API_KEY"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private var model = "gemini-2.5-flash-preview-05-20"
    private var modelFallback = "gemini-2.5-flash-preview-04-17"
    
    init() {
        loadAPIKey()
    }
    
    func loadAPIKey() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai/config.json")
        
        if let data = try? Data(contentsOf: configPath),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = config["gemini_api_key"] as? String,
           !key.isEmpty {
            self.apiKey = key
        }
    }
    
    func updateAPIKey(_ newKey: String) {
        self.apiKey = newKey
        saveAPIKey(newKey)
    }
    
    private func saveAPIKey(_ key: String) {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai")
        let configPath = configDir.appendingPathComponent("config.json")
        
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let config = ["gemini_api_key": key]
        if let data = try? JSONSerialization.data(withJSONObject: config) {
            try? data.write(to: configPath)
        }
    }
    
    struct GeminiRequest: Encodable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
        let systemInstruction: SystemInstruction?
        
        struct Content: Encodable {
            let parts: [Part]
        }
        
        struct Part: Encodable {
            let text: String
        }
        
        struct GenerationConfig: Encodable {
            let temperature: Double
            let maxOutputTokens: Int
            let topP: Double
            let topK: Int
        }
        
        struct SystemInstruction: Encodable {
            let parts: [Part]
        }
    }
    
    struct GeminiResponse: Decodable {
        let candidates: [Candidate]?
        
        struct Candidate: Decodable {
            let content: Content
        }
        
        struct Content: Decodable {
            let parts: [Part]
        }
        
        struct Part: Decodable {
            let text: String
        }
    }
    
    func executeAgentTask(task: String, context: String, capability: AgentCapability) async throws -> String {
        let systemPrompt = getSystemPrompt(for: capability)
        
        let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [GeminiRequest.Content(parts: [GeminiRequest.Part(text: "Context: \(context)\n\nTask: \(task)")])],
            generationConfig: GeminiRequest.GenerationConfig(
                temperature: capability == .codeGeneration ? 0.1 : 0.7,
                maxOutputTokens: 8192,
                topP: 0.95,
                topK: 40
            ),
            systemInstruction: GeminiRequest.SystemInstruction(
                parts: [GeminiRequest.Part(text: systemPrompt)]
            )
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return geminiResponse.candidates?.first?.content.parts.first?.text ?? "No response generated"
                case 400, 404:
                    if model != modelFallback {
                        model = modelFallback
                        return try await executeAgentTask(task: task, context: context, capability: capability)
                    }
                    throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Model not available"])
                case 401:
                    throw NSError(domain: "GeminiAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
                case 429:
                    throw NSError(domain: "GeminiAPI", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"])
                default:
                    throw NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(httpResponse.statusCode)"])
                }
            }
            
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            return geminiResponse.candidates?.first?.content.parts.first?.text ?? "No response generated"
        } catch {
            throw error
        }
    }
    
    private func getSystemPrompt(for capability: AgentCapability) -> String {
        switch capability {
        case .research:
            return "You are an expert research assistant. Analyze web content, extract key information, fact-check claims, and provide comprehensive research summaries with citations."
        case .formFilling:
            return "You are a form-filling assistant. Analyze forms, understand field requirements, and provide appropriate values based on context and user data."
        case .contentExtraction:
            return "You are a content extraction specialist. Extract structured data from web pages, identify key entities, dates, prices, and organize information in a useful format."
        case .taskAutomation:
            return "You are a task automation expert. Break down complex tasks into steps, identify required actions, and provide executable instructions."
        case .smartNavigation:
            return "You are a navigation assistant. Predict user intent, suggest relevant pages, and optimize browsing paths."
        case .contentCreation:
            return "You are a content creation assistant. Generate high-quality content based on context, maintain tone consistency, and ensure accuracy."
        case .dataAnalysis:
            return "You are a data analysis expert. Analyze patterns, create visualizations, and provide insights from web data."
        case .codeGeneration:
            return "You are a code generation expert. Write clean, efficient code based on requirements. Always include error handling and best practices."
        }
    }
}

// MARK: - Smart Agent System
class SmartAgent: ObservableObject {
    @Published var isExecuting = false
    @Published var currentTask = ""
    @Published var taskProgress: Double = 0.0
    @Published var results: [String: Any] = [:]
    @Published var isRecording = false
    @Published var recordedActions: [AutomationAction] = []
    @Published var executionLog: [String] = []
    
    private let geminiService: GeminiAPIService
    private var actionRecorder: ActionRecorder?
    
    init(geminiService: GeminiAPIService) {
        self.geminiService = geminiService
        self.actionRecorder = ActionRecorder()
    }
    
    // MARK: - Automation Recording & Execution
    
    struct AutomationAction: Identifiable, Codable {
        var id = UUID()
        let type: ActionType
        let selector: String?
        let value: String?
        let url: String?
        let timestamp: Date
        let description: String
        
        enum ActionType: String, Codable {
            case click, type, select, navigate, scroll, wait, extract, verify
        }
        
        enum CodingKeys: String, CodingKey {
            case id, type, selector, value, url, timestamp, description
        }
    }
    
    class ActionRecorder {
        var isRecording = false
        var actions: [AutomationAction] = []
        
        func startRecording() {
            isRecording = true
            actions.removeAll()
        }
        
        func stopRecording() -> [AutomationAction] {
            isRecording = false
            return actions
        }
        
        func recordAction(_ action: AutomationAction) {
            if isRecording {
                actions.append(action)
            }
        }
    }
    
    func startRecording() {
        isRecording = true
        recordedActions.removeAll()
        actionRecorder?.startRecording()
        currentTask = "Recording actions..."
    }
    
    func stopRecording() async throws -> TaskAutomationResult {
        isRecording = false
        let actions = actionRecorder?.stopRecording() ?? []
        recordedActions = actions
        
        // Generate intelligent automation script from recorded actions
        let script = try await generateAutomationScript(from: actions)
        
        return TaskAutomationResult(
            task: "Recorded Automation",
            steps: actions.map { $0.description },
            automationScript: script
        )
    }
    
    func executeAutomation(_ automation: TaskAutomationResult, on webView: WKWebView) async throws {
        isExecuting = true
        currentTask = "Executing automation..."
        executionLog.removeAll()
        
        // Parse and execute the automation script
        let actions = parseAutomationScript(automation.automationScript)
        
        for (index, action) in actions.enumerated() {
            taskProgress = Double(index) / Double(actions.count)
            
            switch action.type {
            case .click:
                try await executeClick(action, on: webView)
            case .type:
                try await executeType(action, on: webView)
            case .select:
                try await executeSelect(action, on: webView)
            case .navigate:
                try await executeNavigate(action, on: webView)
            case .scroll:
                try await executeScroll(action, on: webView)
            case .wait:
                try await executeWait(action)
            case .extract:
                try await executeExtract(action, on: webView)
            case .verify:
                try await executeVerify(action, on: webView)
            }
            
            executionLog.append("✅ \(action.description)")
        }
        
        taskProgress = 1.0
        isExecuting = false
        currentTask = "Automation complete"
    }
    
    private func executeClick(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let selector = action.selector else { return }
        
        let js = """
        (function() {
            const element = document.querySelector('\(selector)');
            if (element) {
                element.click();
                return true;
            }
            return false;
        })();
        """
        
        let result = try await webView.evaluateJavaScript(js)
        if let success = result as? Bool, !success {
            throw NSError(domain: "Automation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Element not found: \(selector)"])
        }
    }
    
    private func executeType(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let selector = action.selector, let value = action.value else { return }
        
        let js = """
        (function() {
            const element = document.querySelector('\(selector)');
            if (element) {
                element.value = '\(value)';
                element.dispatchEvent(new Event('input', { bubbles: true }));
                element.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            return false;
        })();
        """
        
        try await webView.evaluateJavaScript(js)
    }
    
    private func executeSelect(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let selector = action.selector, let value = action.value else { return }
        
        let js = """
        (function() {
            const element = document.querySelector('\(selector)');
            if (element && element.tagName === 'SELECT') {
                element.value = '\(value)';
                element.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            return false;
        })();
        """
        
        try await webView.evaluateJavaScript(js)
    }
    
    private func executeNavigate(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let urlString = action.url, let url = URL(string: urlString) else { return }
        
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                webView.load(URLRequest(url: url))
                continuation.resume()
            }
        }
        
        // Wait for page load
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }
    
    private func executeScroll(_ action: AutomationAction, on webView: WKWebView) async throws {
        let js = """
        window.scrollTo({
            top: \(action.value ?? "0"),
            behavior: 'smooth'
        });
        """
        
        try await webView.evaluateJavaScript(js)
    }
    
    private func executeWait(_ action: AutomationAction) async throws {
        if let waitTime = action.value, let seconds = Double(waitTime) {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
    
    private func executeExtract(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let selector = action.selector else { return }
        
        let js = """
        (function() {
            const elements = document.querySelectorAll('\(selector)');
            return Array.from(elements).map(el => ({
                text: el.textContent,
                value: el.value || el.getAttribute('value'),
                href: el.href,
                src: el.src
            }));
        })();
        """
        
        let result = try await webView.evaluateJavaScript(js)
        results["extracted_data"] = result
    }
    
    private func executeVerify(_ action: AutomationAction, on webView: WKWebView) async throws {
        guard let selector = action.selector else { return }
        
        let js = """
        (function() {
            const element = document.querySelector('\(selector)');
            return element !== null;
        })();
        """
        
        let exists = try await webView.evaluateJavaScript(js) as? Bool ?? false
        if !exists {
            throw NSError(domain: "Automation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Verification failed: Element not found"])
        }
    }
    
    private func generateAutomationScript(from actions: [AutomationAction]) async throws -> String {
        let actionsDescription = actions.map { action in
            "\(action.type.rawValue): \(action.description)"
        }.joined(separator: "\n")
        
        let script = try await geminiService.executeAgentTask(
            task: """
            Generate a complete automation script based on these recorded actions:
            \(actionsDescription)
            
            Create a script that:
            1. Includes error handling
            2. Has wait conditions for elements
            3. Uses reliable selectors
            4. Can be exported as Selenium, Puppeteer, or Playwright code
            5. Includes comments explaining each step
            """,
            context: "Browser automation for web testing and task automation",
            capability: .codeGeneration
        )
        
        return script
    }
    
    private func parseAutomationScript(_ script: String) -> [AutomationAction] {
        // Parse the script and convert to automation actions
        // This is a simplified version - in production, use proper parsing
        var actions: [AutomationAction] = []
        
        let lines = script.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("click(") {
                if let selector = extractSelector(from: line) {
                    actions.append(AutomationAction(
                        type: .click,
                        selector: selector,
                        value: nil,
                        url: nil,
                        timestamp: Date(),
                        description: "Click on \(selector)"
                    ))
                }
            } else if line.contains("type(") || line.contains("sendKeys(") {
                if let (selector, value) = extractSelectorAndValue(from: line) {
                    actions.append(AutomationAction(
                        type: .type,
                        selector: selector,
                        value: value,
                        url: nil,
                        timestamp: Date(),
                        description: "Type '\(value)' into \(selector)"
                    ))
                }
            }
        }
        
        return actions
    }
    
    private func extractSelector(from line: String) -> String? {
        // Extract selector from code line
        if let start = line.firstIndex(of: "'") ?? line.firstIndex(of: "\""),
           let end = line.lastIndex(of: "'") ?? line.lastIndex(of: "\""),
           start < end {
            return String(line[line.index(after: start)..<end])
        }
        return nil
    }
    
    private func extractSelectorAndValue(from line: String) -> (String, String)? {
        // Extract selector and value from code line
        let components = line.components(separatedBy: ",")
        if components.count >= 2 {
            let selector = extractSelector(from: components[0]) ?? ""
            let value = extractSelector(from: components[1]) ?? ""
            return (selector, value)
        }
        return nil
    }
    
    // MARK: - Replay recorded actions directly
    /// Executes an array of previously recorded `AutomationAction` objects
    /// without re‑generating or parsing an automation script. This is needed
    /// for one‑click replays from the Automation Manager.
    func executeRecordedActions(_ actions: [AutomationAction], on webView: WKWebView) async throws {
        isExecuting = true
        currentTask = "Replaying recorded actions..."
        executionLog.removeAll()

        for (index, action) in actions.enumerated() {
            taskProgress = Double(index) / Double(actions.count)

            switch action.type {
            case .click:   try await executeClick(action, on: webView)
            case .type:    try await executeType(action, on: webView)
            case .select:  try await executeSelect(action, on: webView)
            case .navigate:try await executeNavigate(action, on: webView)
            case .scroll:  try await executeScroll(action, on: webView)
            case .wait:    try await executeWait(action)
            case .extract: try await executeExtract(action, on: webView)
            case .verify:  try await executeVerify(action, on: webView)
            }

            executionLog.append("✅ \(action.description)")
        }

        taskProgress = 1.0
        isExecuting = false
        currentTask = "Recorded actions complete"
    }

    // MARK: - Original methods enhanced
    
    func executeResearch(topic: String, depth: String = "comprehensive") async throws -> ResearchResult {
        isExecuting = true
        currentTask = "Researching: \(topic)"
        
        // Multi-stage research with parallel execution
        async let researchPlan = geminiService.executeAgentTask(
            task: "Create a comprehensive research plan for: \(topic). Include: 1) Key questions to answer, 2) Types of sources to check, 3) Data points to collect, 4) Potential biases to watch for",
            context: "Research depth: \(depth). Focus on actionable insights.",
            capability: .research
        )
        
        async let initialAnalysis = geminiService.executeAgentTask(
            task: "Provide initial analysis and context for: \(topic). Include historical background, current state, and future implications.",
            context: "Comprehensive overview needed",
            capability: .research
        )
        
        let (plan, analysis) = try await (researchPlan, initialAnalysis)
        
        taskProgress = 0.3
        
        // Deep dive with multiple perspectives
        async let expertPerspective = geminiService.executeAgentTask(
            task: "Analyze \(topic) from an expert perspective. Include technical details, industry insights, and professional opinions.",
            context: plan + "\n" + analysis,
            capability: .research
        )
        
        async let controversies = geminiService.executeAgentTask(
            task: "Identify controversies, debates, and different viewpoints about: \(topic)",
            context: analysis,
            capability: .research
        )
        
        async let dataAnalysis = geminiService.executeAgentTask(
            task: "Extract and analyze numerical data, statistics, and trends related to: \(topic)",
            context: analysis,
            capability: .dataAnalysis
        )
        
        let (expert, contro, data) = try await (expertPerspective, controversies, dataAnalysis)
        
        taskProgress = 0.7
        
        // Synthesis and recommendations
        let synthesis = try await geminiService.executeAgentTask(
            task: """
            Synthesize all research on \(topic) into:
            1. Executive summary (3-4 paragraphs)
            2. Key findings (bullet points)
            3. Actionable recommendations
            4. Areas for further research
            5. Confidence level assessment
            """,
            context: [plan, analysis, expert, contro, data].joined(separator: "\n\n"),
            capability: .contentCreation
        )
        
        taskProgress = 1.0
        isExecuting = false
        
        return ResearchResult(
            topic: topic,
            summary: synthesis,
            keyFindings: expert + "\n\n" + contro,
            sources: extractSources(from: [analysis, expert, contro].joined(separator: " "))
        )
    }
    
    func automateTask(description: String, pageContent: String) async throws -> TaskAutomationResult {
        isExecuting = true
        currentTask = "Analyzing task: \(description)"
        
        // Enhanced task analysis with multiple approaches
        async let taskBreakdown = geminiService.executeAgentTask(
            task: """
            Break down this task into executable steps: \(description)
            For each step provide:
            1. Action type (click, type, select, wait, verify)
            2. Target element (CSS selector or XPath)
            3. Input data if needed
            4. Success criteria
            5. Error handling approach
            """,
            context: pageContent,
            capability: .taskAutomation
        )
        
        async let alternativeApproaches = geminiService.executeAgentTask(
            task: "Suggest 3 different approaches to automate: \(description). Compare pros and cons of each.",
            context: pageContent,
            capability: .taskAutomation
        )
        
        let (breakdown, alternatives) = try await (taskBreakdown, alternativeApproaches)
        
        taskProgress = 0.5
        
        // Generate multiple automation scripts
        async let seleniumScript = geminiService.executeAgentTask(
            task: "Generate Selenium WebDriver script for: \(description)",
            context: breakdown,
            capability: .codeGeneration
        )
        
        async let playwrightScript = geminiService.executeAgentTask(
            task: "Generate Playwright script for: \(description)",
            context: breakdown,
            capability: .codeGeneration
        )
        
        async let javascriptAutomation = geminiService.executeAgentTask(
            task: "Generate pure JavaScript automation script that can run in browser console for: \(description)",
            context: breakdown,
            capability: .codeGeneration
        )
        
        let (selenium, playwright, jsAuto) = try await (seleniumScript, playwrightScript, javascriptAutomation)
        
        taskProgress = 1.0
        isExecuting = false
        
        let combinedScript = """
        // === BROWSER CONSOLE SCRIPT ===
        \(jsAuto)
        
        // === SELENIUM VERSION ===
        \(selenium)
        
        // === PLAYWRIGHT VERSION ===
        \(playwright)
        
        // === ALTERNATIVE APPROACHES ===
        \(alternatives)
        """
        
        return TaskAutomationResult(
            task: description,
            steps: parseSteps(from: breakdown),
            automationScript: combinedScript
        )
    }
    
    func extractStructuredData(from pageContent: String, requirements: String = "all") async throws -> [String: Any] {
        isExecuting = true
        currentTask = "Extracting structured data..."
        
        let extraction = try await geminiService.executeAgentTask(
            task: """
            Extract structured data from this page based on requirements: \(requirements)
            
            Return as JSON with these categories:
            1. contact_info: {emails: [], phones: [], addresses: []}
            2. financial_data: {prices: [], currencies: [], percentages: []}
            3. temporal_data: {dates: [], times: [], durations: []}
            4. entities: {people: [], companies: [], products: []}
            5. metadata: {title, description, keywords, author}
            6. tables: [array of table data as JSON]
            7. lists: [structured lists found on page]
            8. forms: [form fields and their properties]
            """,
            context: pageContent,
            capability: .contentExtraction
        )
        
        // Parse JSON response
        if let data = extraction.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            results = json
            isExecuting = false
            return json
        }
        
        isExecuting = false
        return ["error": "Failed to parse extraction results"]
    }
    
    private func extractSources(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) ?? []
        
        var sources = matches.compactMap { match -> String? in
            if let range = Range(match.range, in: text) {
                return String(text[range])
            }
            return nil
        }
        
        // Also extract domain names mentioned in text
        let domainPattern = #"\b(?:www\.)?([a-zA-Z0-9-]+\.(?:com|org|net|edu|gov|co|io|ai))\b"#
        if let regex = try? NSRegularExpression(pattern: domainPattern) {
            let domainMatches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in domainMatches {
                if let range = Range(match.range, in: text) {
                    sources.append("https://\(text[range])")
                }
            }
        }
        
        return Array(Set(sources)) // Remove duplicates
    }
    
    private func parseSteps(from text: String) -> [String] {
        // Enhanced step parsing
        let lines = text.components(separatedBy: .newlines)
        var steps: [String] = []
        let actionKeywords = ["click", "type", "select", "navigate", "wait", "verify", "extract"]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                // Look for numbered steps, bullet points, or action keywords
                let hasActionKeyword = actionKeywords.contains { keyword in
                    trimmed.lowercased().contains(keyword)
                }
                
                if trimmed.range(of: #"^\d+\."#, options: .regularExpression) != nil ||
                   trimmed.hasPrefix("-") || trimmed.hasPrefix("•") ||
                   trimmed.hasPrefix("*") || trimmed.hasPrefix("→") ||
                   hasActionKeyword {
                    steps.append(trimmed)
                }
            }
        }
        
        return steps.isEmpty ? text.components(separatedBy: ". ").filter { !$0.isEmpty } : steps
    }
}

// MARK: - Data Models
struct ResearchResult: Identifiable {
    let id = UUID()
    let topic: String
    let summary: String
    let keyFindings: String
    let sources: [String]
    let timestamp = Date()
}

struct TaskAutomationResult: Identifiable {
    let id = UUID()
    let task: String
    let steps: [String]
    let automationScript: String
    let timestamp = Date()
}

struct SmartBookmark: Identifiable, Codable {
    var id = UUID()
    let url: String
    let title: String
    let category: String
    let tags: [String]
    let aiSummary: String
    let importance: Double
    let lastAccessed: Date
    let accessCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, url, title, category, tags, aiSummary, importance, lastAccessed, accessCount
    }
}

struct BrowserWorkflow: Identifiable {
    let id = UUID()
    let name: String
    let steps: [WorkflowStep]
    let triggers: [WorkflowTrigger]
}

struct WorkflowStep {
    let action: String
    let parameters: [String: Any]
}

struct WorkflowTrigger {
    let type: String
    let condition: String
}

// MARK: - No‑op JS Message Handler
/// Provides a default WKScriptMessageHandler so we can register
/// message channels even before a concrete coordinator is attached.
class DummyHandler: NSObject, WKScriptMessageHandler {
    static let shared = DummyHandler()
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {}
}

// MARK: - Advanced Tab Manager
class AdvancedTabManager: ObservableObject {
    @Published var tabs: [SmartTab] = []
    @Published var activeTabId: UUID?
    @Published var tabGroups: [TabGroup] = []
    @Published var workflows: [BrowserWorkflow] = []
    
    struct SmartTab: Identifiable {
        let id = UUID()
        let webView: WKWebView
        var title: String = "New Tab"
        var url: String = "https://www.google.com"
        var aiContext: String = ""
        var relatedTabs: [UUID] = []
        var purpose: TabPurpose = .general
        var automationEnabled = false
        
        init(url: String = "https://www.google.com", purpose: TabPurpose = .general) {
            self.url = url
            self.purpose = purpose

            // Configure WebView with content controller for recording
            let config = WKWebViewConfiguration()

            // === Content controller for AI helpers ===
            let contentController = WKUserContentController()

            // Inject JS to detect right‑clicks on any YouTube link/thumbnail.
            let scriptSource = """
            document.addEventListener('contextmenu', function(e) {
              const link = e.target.closest('a[href*=\\"youtube.com/watch\\"]');
              if (link) {
                window.webkit.messageHandlers.ytContext.postMessage(link.href);
              }
            }, true);
            """
            let userScript = WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
            contentController.addUserScript(userScript)

            // Register a no‑op handler; the real coordinator will override.
            contentController.add(DummyHandler.shared, name: "ytContext")

            config.userContentController = contentController

            // Add message handler for recording (simplified for compilation)
            self.webView = WKWebView(frame: .zero, configuration: config)
            self.title = "New Tab"
        }
    }
    
    struct TabGroup: Identifiable {
        let id = UUID()
        var name: String
        var tabIds: [UUID]
        var color: Color
        var isCollapsed = false
    }
    
    enum TabPurpose {
        case general, research, shopping, work, entertainment, development
    }
    
    var activeTab: SmartTab? {
        tabs.first { $0.id == activeTabId }
    }
    
    func createSmartTab(url: String? = nil, purpose: TabPurpose = .general) {
        let newTab = SmartTab(
            url: url ?? "https://www.google.com",
            purpose: purpose
        )
        tabs.append(newTab)
        activeTabId = newTab.id
    }
    
    func createTabGroup(name: String, tabIds: [UUID], color: Color = .blue) {
        let group = TabGroup(name: name, tabIds: tabIds, color: color)
        tabGroups.append(group)
    }
    
    func suggestRelatedTabs(for tabId: UUID) -> [SmartTab] {
        guard let tab = tabs.first(where: { $0.id == tabId }) else { return [] }
        
        return tabs.filter { otherTab in
            otherTab.id != tabId &&
            (otherTab.purpose == tab.purpose ||
             otherTab.aiContext.contains(where: { tab.aiContext.contains($0) }))
        }
    }
}

// MARK: - Browser View Model
@MainActor
class BrowserViewModel: ObservableObject {
    /// Export the current AI response to a simple PDF file.
    func exportAIPanelToPDF() {
        guard !aiResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Create a temporary NSTextView to render the markdown/text.
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.string = aiResponse
        textView.font = NSFont.systemFont(ofSize: 12)
        
        let pdfData = textView.dataWithPDF(inside: textView.bounds)
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["pdf"]
        savePanel.nameFieldStringValue = "AI_Summary.pdf"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? pdfData.write(to: url)
        }
    }

    /// Export the latest research summary to PDF (includes topic title).
    func exportLatestResearchToPDF() {
        guard let latest = researchResults.first else { return }

        // Prepare Markdown string
        let md = """
        # Research Report – \(latest.topic)

        ## Executive Summary
        \(latest.summary)

        ## Key Findings
        \(latest.keyFindings)

        ## Sources
        \(latest.sources.joined(separator: "\n"))
        """

        // Render in a temporary NSTextView
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        textView.string = md
        textView.font = NSFont.systemFont(ofSize: 12)

        let pdfData = textView.dataWithPDF(inside: textView.bounds)

        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["pdf"]
        savePanel.nameFieldStringValue = "Research_\(latest.topic.replacingOccurrences(of: " ", with: "_")).pdf"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? pdfData.write(to: url)
        }
    }
    @Published var currentURL = "https://www.google.com"
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showAIPanel = false
    @Published var showAgentPanel = false
    @Published var showResearchPanel = false
    @Published var showWorkflowPanel = false
    @Published var aiResponse = ""
    @Published var pageContent = ""
    @Published var pageAnalysis = ""
    @Published var showAPIKeyAlert = false
    @Published var researchResults: [ResearchResult] = []
    @Published var automationResults: [TaskAutomationResult] = []
    @Published var smartBookmarks: [SmartBookmark] = []
    @Published var selectedAgent: AgentCapability = .research
    @Published var automationScripts: [SavedAutomation] = []
    @Published var showAutomationPanel = false
    
    struct SavedAutomation: Identifiable, Codable {
        var id = UUID()
        let name: String
        let description: String
        let script: String
        let actions: [SmartAgent.AutomationAction]
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case id, name, description, script, actions, createdAt
        }
    }
    
    let geminiService = GeminiAPIService()
    let smartAgent: SmartAgent
    let tabManager = AdvancedTabManager()
    
    init() {
        self.smartAgent = SmartAgent(geminiService: geminiService)
        tabManager.createSmartTab()
        loadSmartBookmarks()
        loadAutomations()
    }
    
    func navigateTo(_ urlString: String) {
        var finalURL = urlString
        
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                finalURL = "https://\(urlString)"
            } else {
                finalURL = "https://www.google.com/search?q=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }
        }
        
        if let url = URL(string: finalURL), let tab = tabManager.activeTab {
            tab.webView.load(URLRequest(url: url))
            currentURL = finalURL
            searchText = finalURL
            
            // Auto-analyze page for agent capabilities
            Task {
                await analyzePageForAgents()
            }
        }
    }
    
    func executeSmartAction(_ action: String) async {
        switch action {
        case "research":
            await performResearch()
        case "automate":
            if smartAgent.isRecording {
                await stopRecording()
            } else {
                showAutomationPanel = true
            }
        case "extract":
            await extractPageData()
        case "analyze":
            await analyzePageContent()
        case "workflow":
            showWorkflowPanel = true
        case "record":
            if smartAgent.isRecording {
                await stopRecording()
            } else {
                startRecording()
            }
        case "youtube":
            self.summarizeYouTube()
        default:
            break
        }
    }
    
    func startRecording() {
        smartAgent.startRecording()
        showAgentPanel = true
    }
    
    func stopRecording() async {
        do {
            let automation = try await smartAgent.stopRecording()
            
            // Save the automation
            let saved = SavedAutomation(
                name: "Automation \(Date().formatted(date: .abbreviated, time: .shortened))",
                description: automation.task,
                script: automation.automationScript,
                actions: smartAgent.recordedActions,
                createdAt: Date()
            )
            
            automationScripts.append(saved)
            saveAutomations()
            
            automationResults.insert(automation, at: 0)
            showAgentPanel = true
        } catch {
            aiResponse = "Recording failed: \(error.localizedDescription)"
            showAIPanel = true
        }
    }
    
    func executeAutomation(_ automation: SavedAutomation) async {
        do {
            guard let webView = tabManager.activeTab?.webView else { return }
            try await smartAgent.executeRecordedActions(automation.actions, on: webView)
            showAgentPanel = true
        } catch {
            aiResponse = "Execution failed: \(error.localizedDescription)"
            showAIPanel = true
        }
    }
    
    func saveAutomations() {
        let automationsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai")
        let automationsPath = automationsDir.appendingPathComponent("automations.json")
        
        try? FileManager.default.createDirectory(at: automationsDir, withIntermediateDirectories: true)
        
        if let data = try? JSONEncoder().encode(automationScripts) {
            try? data.write(to: automationsPath)
        }
    }
    
    private func loadAutomations() {
        let automationsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai/automations.json")
        
        if let data = try? Data(contentsOf: automationsPath),
           let automations = try? JSONDecoder().decode([SavedAutomation].self, from: data) {
            self.automationScripts = automations
        }
    }
    
    private func performResearch() async {
        guard !pageContent.isEmpty else { return }
        
        do {
            let topic = tabManager.activeTab?.title ?? "Current Page"
            let result = try await smartAgent.executeResearch(topic: topic, depth: "comprehensive")
            researchResults.insert(result, at: 0)
            showResearchPanel = true
        } catch {
            aiResponse = "Research failed: \(error.localizedDescription)"
            showAIPanel = true
        }
    }
    
    private func automateCurrentPage() async {
        do {
            let result = try await smartAgent.automateTask(
                description: "Automate common actions on this page",
                pageContent: pageContent
            )
            automationResults.insert(result, at: 0)
            showAgentPanel = true
        } catch {
            aiResponse = "Automation failed: \(error.localizedDescription)"
            showAIPanel = true
        }
    }
    
    private func extractPageData() async {
        do {
            let extractedData = try await smartAgent.extractStructuredData(
                from: pageContent,
                requirements: "Extract all available data including contacts, prices, dates, entities, and tables"
            )
            
            // Format the extracted data nicely
            var formattedOutput = "📊 Structured Data Extraction\n\n"
            
            for (category, data) in extractedData {
                formattedOutput += "**\(category.replacingOccurrences(of: "_", with: " ").capitalized)**\n"
                
                if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    formattedOutput += "```json\n\(jsonString)\n```\n\n"
                } else {
                    formattedOutput += "\(data)\n\n"
                }
            }
            
            aiResponse = formattedOutput
            showAIPanel = true
        } catch {
            aiResponse = "Extraction failed: \(error.localizedDescription)"
            showAIPanel = true
        }
    }
    
    private func analyzePageContent() async {
    /// Summarize the current YouTube video using Gemini.
    
        do {
            pageAnalysis = try await geminiService.executeAgentTask(
                task: "Provide a comprehensive analysis of this webpage including: purpose, target audience, key messages, credibility assessment, potential biases, and actionable insights.",
                context: pageContent,
                capability: .dataAnalysis
            )
            showAIPanel = true
        } catch {
            pageAnalysis = "Analysis failed: \(error.localizedDescription)"
        }
    }
    
    func analyzePageForAgents() async {
        // Auto-detect what agents would be useful for this page
        do {
            let suggestion = try await geminiService.executeAgentTask(
                task: "Analyze this page and suggest which AI agents would be most useful (research, automation, data extraction, etc)",
                context: String(pageContent.prefix(2000)),
                capability: .smartNavigation
            )
            
            // Update UI based on suggestions
            await MainActor.run {
                self.pageAnalysis = suggestion
            }
        } catch {
            print("Agent analysis failed: \(error)")
        }
    }
    
    func createSmartBookmark() async {
        guard let tab = tabManager.activeTab else { return }
        
        do {
            let analysis = try await geminiService.executeAgentTask(
                task: "Analyze this page and provide: 1) Best category, 2) Relevant tags (comma separated), 3) One-line summary, 4) Importance score (0-1)",
                context: pageContent,
                capability: .contentExtraction
            )
            
            let components = analysis.components(separatedBy: "\n")
            let category = components.first ?? "General"
            let tags = components.dropFirst().first?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let summary = components.dropFirst(2).first ?? "Saved page"
            let importance = Double(components.dropFirst(3).first ?? "0.5") ?? 0.5
            
            let bookmark = SmartBookmark(
                url: tab.url,
                title: tab.title,
                category: category,
                tags: tags,
                aiSummary: summary,
                importance: importance,
                lastAccessed: Date(),
                accessCount: 1
            )
            
            smartBookmarks.append(bookmark)
            saveSmartBookmarks()
        } catch {
            print("Smart bookmark creation failed: \(error)")
        }
    }
    
    private func loadSmartBookmarks() {
        let bookmarksPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai/bookmarks.json")
        
        if let data = try? Data(contentsOf: bookmarksPath),
           let bookmarks = try? JSONDecoder().decode([SmartBookmark].self, from: data) {
            self.smartBookmarks = bookmarks
        }
    }
    
    private func saveSmartBookmarks() {
        let bookmarksDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".nexusai")
        let bookmarksPath = bookmarksDir.appendingPathComponent("bookmarks.json")
        
        try? FileManager.default.createDirectory(at: bookmarksDir, withIntermediateDirectories: true)
        
        if let data = try? JSONEncoder().encode(smartBookmarks) {
            try? data.write(to: bookmarksPath)
        }
    }
}
// MARK: - YouTube & Workflow Helpers
extension BrowserViewModel {
    /// Summarize whichever YouTube video is currently playing or visible.
    @MainActor
    func summarizeYouTube() {
        showAIPanel = true
        aiResponse = "⏳ Detecting video URL…"

        guard let webView = tabManager.activeTab?.webView else {
            aiResponse = "🎬 No active web view."
            return
        }

        let js = """
        (() => {
            const live = window.location.href;
            if (/watch|shorts/.test(live)) return live;
            const canon = document.querySelector('link[rel="canonical"]')?.href || '';
            if (/watch|shorts/.test(canon)) return canon;
            const og = document.querySelector('meta[property="og:url"]')?.content || '';
            if (/watch|shorts/.test(og)) return og;
            return '';
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            // Determine the URL to summarize
            let urlString: String
            if let str = result as? String, !str.isEmpty {
                urlString = str
            } else if let live = webView.url?.absoluteString,
                      live.contains("/watch") || live.contains("/shorts") {
                urlString = live
            } else {
                DispatchQueue.main.async {
                    self.aiResponse = "🎬 Unable to detect a YouTube video URL."
                }
                return
            }

            // Offload the heavy network call
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                await MainActor.run { self.aiResponse = "⏳ Summarizing video…" }
                do {
                    let summary = try await self.geminiService.executeAgentTask(
                        task: """
                        Summarize the YouTube video at: \(urlString)
                        • Fetch transcript
                        • Provide timestamps and 3-5 key insights
                        """,
                        context: "",
                        capability: .contentExtraction
                    )
                    await MainActor.run { self.aiResponse = summary }
                } catch {
                    await MainActor.run {
                        self.aiResponse = "⚠️ Summarization failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    /// Summarize a specific YouTube URL (used by right-click).
    @MainActor
    func summarizeYouTube(urlString: String) async {
        showAIPanel = true
        aiResponse = "⏳ Summarizing video…"
        do {
            let summary = try await geminiService.executeAgentTask(
                task: """
                Summarize the YouTube video at: \(urlString)
                • Fetch transcript
                • Provide timestamps and 3‑5 key insights
                """,
                context: "",
                capability: .contentExtraction
            )
            aiResponse = summary
        } catch {
            aiResponse = "⚠️ Summarization failed: \(error.localizedDescription)"
        }
    }

    /// Turn a natural-language prompt into a saved workflow.
    @MainActor
    func createCustomWorkflow(from prompt: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        showWorkflowPanel = false
        showAIPanel = true
        aiResponse = "⌛ Creating workflow…"

        do {
            let json = try await geminiService.executeAgentTask(
                task: """
                Convert the request into an array of JSON workflow steps with:
                {\"action\": \"verb\", \"parameters\": {...}}
                Respond only with JSON.
                Request: \(trimmed)
                """,
                context: "",
                capability: .taskAutomation
            )

            guard let data = json.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw NSError(domain: "WorkflowParse", code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Gemini JSON invalid"])
            }

            let steps = array.map { dict -> WorkflowStep in
                WorkflowStep(action: dict["action"] as? String ?? "unknown",
                             parameters: dict["parameters"] as? [String: Any] ?? [:])
            }

            let workflow = BrowserWorkflow(
                name: String(trimmed.prefix(40)) + (trimmed.count > 40 ? "…" : ""),
                steps: steps,
                triggers: []
            )

            tabManager.workflows.append(workflow)
            aiResponse = "✅ Workflow created with \(steps.count) steps."
        } catch {
            aiResponse = "⚠️ Failed to create workflow: \(error.localizedDescription)"
        }
    }
}
// MARK: - Web View Coordinator
class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let parent: WebView
    
    init(_ parent: WebView) {
        self.parent = parent
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.browserModel.isLoading = false
        
        if let url = webView.url?.absoluteString {
            parent.browserModel.currentURL = url
            parent.browserModel.searchText = url
        }
        
        if let title = webView.title,
           let index = parent.browserModel.tabManager.tabs.firstIndex(where: { $0.webView === webView }) {
            parent.browserModel.tabManager.tabs[index].title = title
            parent.browserModel.tabManager.tabs[index].url = webView.url?.absoluteString ?? ""
        }
        
        // Enhanced content extraction
        let jsCode = """
        (function() {
            let content = document.body.innerText || '';
            let meta = {
                title: document.title,
                description: document.querySelector('meta[name="description"]')?.content || '',
                keywords: document.querySelector('meta[name="keywords"]')?.content || '',
                author: document.querySelector('meta[name="author"]')?.content || '',
                images: Array.from(document.images).slice(0, 5).map(img => img.src),
                links: Array.from(document.links).slice(0, 10).map(a => ({url: a.href, text: a.textContent}))
            };
            return JSON.stringify({content: content, meta: meta});
        })();
        """
        
        webView.evaluateJavaScript(jsCode) { result, error in
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? String {
                Task { @MainActor in
                    self.parent.browserModel.pageContent = String(content.prefix(10000))
                    
                    // Auto-analyze for agent capabilities
                    await self.parent.browserModel.analyzePageForAgents()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.browserModel.isLoading = true
        parent.browserModel.pageContent = ""
        parent.browserModel.pageAnalysis = ""
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            parent.browserModel.tabManager.createSmartTab(url: navigationAction.request.url?.absoluteString)
        }
        return nil
    }
    // Handle JS messages from injected scripts (e.g., right‑click YouTube summaries)
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        if message.name == "ytContext",
           let urlString = message.body as? String {
            Task { @MainActor in
                await parent.browserModel.summarizeYouTube(urlString: urlString)
            }
        }
    }
}

// MARK: - WebView
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    @ObservedObject var browserModel: BrowserViewModel
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Main Browser View
struct BrowserView: View {
    @StateObject private var browserModel = BrowserViewModel()
    @State private var apiKeyInput = ""
    @State private var showSidebar = false
    @State private var sidebarContent: SidebarContent = .bookmarks
    @State private var hoveredAgentAction: String? = nil
    @State private var customWorkflowPrompt: String = ""
    
    enum SidebarContent {
        case bookmarks, research, automation, workflows
    }
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            HStack(spacing: 0) {
                // Sidebar
                if showSidebar {
                    sidebarView
                        .transition(.move(edge: .leading))
                }
                
                // Main Browser Content
                VStack(spacing: 0) {
                    navigationBar
                    
                    ZStack {
                        // Tab Content Area
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                // Smart Tab Bar
                                smartTabBar
                                
                                // Web Content
                                if let activeTab = browserModel.tabManager.activeTab {
                                    ZStack {
                                        WebView(webView: activeTab.webView, browserModel: browserModel)
                                        
                                        // Floating Agent Actions
                                        agentActionsOverlay
                                            .padding()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                                    }
                                }
                            }
                        }
                        
                        // AI Panels
                        if browserModel.showAIPanel {
                            aiAssistantPanel
                        }
                        
                        if browserModel.showResearchPanel {
                            researchPanel
                        }
                        
                        if browserModel.showAgentPanel {
                            agentPanel
                        }
                        
                        if browserModel.showWorkflowPanel {
                            workflowPanel
                        }
                        
                        if browserModel.showAutomationPanel {
                            automationManagerPanel
                        }
                    }
                    
                    // Status Bar
                    statusBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Gemini API Key Required", isPresented: $browserModel.showAPIKeyAlert) {
            TextField("Enter your Gemini API Key", text: $apiKeyInput)
            Button("Save") {
                browserModel.geminiService.updateAPIKey(apiKeyInput)
                browserModel.showAPIKeyAlert = false
            }
            Button("Get Free API Key") {
                NSWorkspace.shared.open(URL(string: "https://makersuite.google.com/app/apikey")!)
            }
            Button("Cancel", role: .cancel) {
                browserModel.showAPIKeyAlert = false
            }
        } message: {
            Text("The default API key has reached its limit. Please enter your own Google Gemini API key.")
        }
    }
    
    var navigationBar: some View {
        HStack(spacing: 12) {
            // Menu Button
            Button(action: { withAnimation { showSidebar.toggle() } }) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(ModernButtonStyle())
            
            // Navigation
            HStack(spacing: 8) {
                Button(action: { browserModel.tabManager.activeTab?.webView.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(ModernButtonStyle())
                .disabled(!(browserModel.tabManager.activeTab?.webView.canGoBack ?? false))
                
                Button(action: { browserModel.tabManager.activeTab?.webView.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(ModernButtonStyle())
                .disabled(!(browserModel.tabManager.activeTab?.webView.canGoForward ?? false))
                
                Button(action: { browserModel.tabManager.activeTab?.webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(ModernButtonStyle())
            }
            
            // Smart URL Bar
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                
                TextField("Search or enter URL", text: $browserModel.searchText, onCommit: {
                    browserModel.navigateTo(browserModel.searchText)
                })
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                
                if browserModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                } else if !browserModel.pageAnalysis.isEmpty {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                        .font(.system(size: 12))
                        .help("AI has suggestions for this page")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            // AI Actions
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        await browserModel.createSmartBookmark()
                    }
                }) {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.yellow)
                }
                .buttonStyle(ModernButtonStyle())
                .help("Smart Bookmark with AI categorization")
                
                Button(action: { browserModel.showAIPanel.toggle() }) {
                    Image(systemName: "cpu")
                        .foregroundColor(.purple)
                }
                .buttonStyle(ModernButtonStyle())
                .help("AI Assistant")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }
    
    var smartTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(browserModel.tabManager.tabs) { tab in
                    SmartTabView(
                        tab: tab,
                        isActive: tab.id == browserModel.tabManager.activeTabId,
                        onSelect: {
                            browserModel.tabManager.activeTabId = tab.id
                            browserModel.currentURL = tab.url
                            browserModel.searchText = tab.url
                        },
                        onClose: {
                            browserModel.tabManager.tabs.removeAll { $0.id == tab.id }
                            if browserModel.tabManager.tabs.isEmpty {
                                browserModel.tabManager.createSmartTab()
                            }
                        }
                    )
                }
                
                Button(action: {
                    browserModel.tabManager.createSmartTab()
                }) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .background(Color.black.opacity(0.6))
    }
    
    var agentActionsOverlay: some View {
        VStack(spacing: 12) {
            // Recording indicator
            if browserModel.smartAgent.isRecording {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 8)
                                .scaleEffect(1.5)
                                .opacity(0)
                                .animation(
                                    Animation.easeOut(duration: 1)
                                        .repeatForever(autoreverses: false),
                                    value: browserModel.smartAgent.isRecording
                                )
                        )
                    
                    Text("Recording...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            ForEach([
                ("cpu", "Research", "research"),
                ("wand.and.stars", "Automate", "automate"),
                ("record.circle", "Record", "record"),
                ("doc.text.magnifyingglass", "Extract", "extract"),
                ("chart.line.uptrend.xyaxis", "Analyze", "analyze"),
                ("flowchart", "Workflow", "workflow"),
                ("play.rectangle", "Summarize", "youtube")
            ], id: \.0) { icon, label, action in
                Button(action: {
                    Task {
                        await browserModel.executeSmartAction(action)
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: action == "record" && browserModel.smartAgent.isRecording ? "stop.circle.fill" : icon)
                            .font(.system(size: 20))
                            .foregroundColor(action == "record" && browserModel.smartAgent.isRecording ? .red : nil)
                        Text(action == "record" && browserModel.smartAgent.isRecording ? "Stop" : label)
                            .font(.system(size: 10))
                    }
                    .frame(width: 60, height: 60)
                    .foregroundColor(hoveredAgentAction == action ? .white : .gray)
                    .background(
                        Circle()
                            .fill(
                                action == "record" && browserModel.smartAgent.isRecording ?
                                LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                hoveredAgentAction == action ? 
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    )
                    .shadow(color: 
                        action == "record" && browserModel.smartAgent.isRecording ? .red.opacity(0.5) :
                        hoveredAgentAction == action ? .purple.opacity(0.5) : .clear, 
                        radius: 10
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(hoveredAgentAction == action ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: hoveredAgentAction)
                .onHover { isHovered in
                    hoveredAgentAction = isHovered ? action : nil
                }
                .help(getAgentHelp(for: action))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.7))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    var sidebarView: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack {
                Text("AI Browser")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { withAnimation { showSidebar = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            // Sidebar Navigation
            VStack(spacing: 2) {
                SidebarButton(
                    icon: "bookmark.fill",
                    title: "Smart Bookmarks",
                    count: browserModel.smartBookmarks.count,
                    isSelected: sidebarContent == .bookmarks,
                    action: { sidebarContent = .bookmarks }
                )
                
                SidebarButton(
                    icon: "doc.text.magnifyingglass",
                    title: "Research History",
                    count: browserModel.researchResults.count,
                    isSelected: sidebarContent == .research,
                    action: { sidebarContent = .research }
                )
                
                SidebarButton(
                    icon: "gearshape.2",
                    title: "Automations",
                    count: browserModel.automationResults.count,
                    isSelected: sidebarContent == .automation,
                    action: { sidebarContent = .automation }
                )
                
                SidebarButton(
                    icon: "flowchart",
                    title: "Workflows",
                    count: browserModel.tabManager.workflows.count,
                    isSelected: sidebarContent == .workflows,
                    action: { sidebarContent = .workflows }
                )
            }
            .padding(.top, 8)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 8)
            
            // Sidebar Content
            ScrollView {
                switch sidebarContent {
                case .bookmarks:
                    bookmarksContent
                case .research:
                    researchContent
                case .automation:
                    automationContent
                case .workflows:
                    workflowsContent
                }
            }
            
            Spacer()
        }
        .frame(width: 280)
        .background(Color.black.opacity(0.9))
    }
    
    var bookmarksContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(browserModel.smartBookmarks.sorted(by: { $0.importance > $1.importance })) { bookmark in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bookmark.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            ForEach(Array(repeating: 0, count: Int(bookmark.importance * 5)), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    Text(bookmark.aiSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Label(bookmark.category, systemImage: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(bookmark.lastAccessed, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(bookmark.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                .onTapGesture {
                    browserModel.navigateTo(bookmark.url)
                }
            }
        }
        .padding()
    }
    
    var researchContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(browserModel.researchResults) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.topic)
                        .font(.system(size: 14, weight: .bold))
                    
                    Text(result.summary)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(4)
                    
                    HStack {
                        Label("\(result.sources.count) sources", systemImage: "link")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Spacer()
                        
                        Text(result.timestamp, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var automationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(browserModel.automationResults) { result in
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.task)
                        .font(.system(size: 14, weight: .bold))
                    
                    Text("\(result.steps.count) steps")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Button("View Script") {
                        browserModel.aiResponse = result.automationScript
                        browserModel.showAIPanel = true
                    }
                    .buttonStyle(ModernButtonStyle())
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var workflowsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browser Workflows")
                .font(.system(size: 14, weight: .bold))
            
            Text("Create automated workflows for repetitive tasks")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Button("Create New Workflow") {
                browserModel.showWorkflowPanel = true
            }
            .buttonStyle(ModernButtonStyle())

            // ── Divider for custom workflow section ──
            Divider()
                .padding(.vertical, 6)

            // ── Custom workflow builder UI ──
            VStack(alignment: .leading, spacing: 6) {
                Text("Create a custom workflow")
                    .font(.system(size: 12, weight: .bold))

                TextField("Describe what you’d like to automate…",
                          text: $customWorkflowPrompt,
                          axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Button(action: {
                    Task {
                        await browserModel.createCustomWorkflow(from: customWorkflowPrompt)
                        customWorkflowPrompt = ""
                    }
                }) {
                    Label("Create Workflow", systemImage: "sparkle")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .disabled(customWorkflowPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .glassCard()
        }
        .padding()
    }
    
    var aiAssistantPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Analysis", systemImage: "cpu")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Button(action: {
                    browserModel.exportAIPanelToPDF()
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Save AI summary as PDF")

                Button(action: {
                    browserModel.showAIPanel = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }

            if !browserModel.pageAnalysis.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Page Intelligence")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple)

                    Text(browserModel.pageAnalysis)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }

            if !browserModel.aiResponse.isEmpty {
                ScrollView {
                    Text(browserModel.aiResponse.asMarkdownAttributed())
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.9))
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 300)
                .padding(10)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(width: 400)
        .glassCard()
        .draggableWindow()
        .offset(x: -20, y: 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    var automationManagerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            automationManagerHeader
            automationManagerControls
            automationManagerContent
        }
        .padding()
        .frame(width: 450)
        .glassCard()
        .draggableWindow()
        .offset(x: -20, y: 180)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    var automationManagerHeader: some View {
        HStack {
            Label("Automation Manager", systemImage: "play.rectangle.fill")
                .font(.system(size: 16, weight: .bold))
            
            Spacer()
            
            Button(action: {
                browserModel.showAutomationPanel = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    var automationManagerControls: some View {
        HStack {
            Button("Start Recording") {
                browserModel.startRecording()
                browserModel.showAutomationPanel = false
            }
            .buttonStyle(ActionButtonStyle())
            .disabled(browserModel.smartAgent.isRecording)
            
            Button("Import") {
                // Import automation
            }
            .buttonStyle(ModernButtonStyle())
        }
    }
    
    var automationManagerContent: some View {
        Group {
            if browserModel.automationScripts.isEmpty {
                automationEmptyState
            } else {
                automationsList
            }
        }
    }
    
    var automationEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No saved automations")
                .font(.system(size: 14))
                .foregroundColor(.gray)
            
            Text("Start recording to create your first automation")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    var automationsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(browserModel.automationScripts) { automation in
                    AutomationListItem(
                        automation: automation,
                        onExecute: {
                            Task {
                                await browserModel.executeAutomation(automation)
                            }
                        },
                        onDelete: {
                            if let index = browserModel.automationScripts.firstIndex(where: { $0.id == automation.id }) {
                                browserModel.automationScripts.remove(at: index)
                                browserModel.saveAutomations()
                            }
                        }
                    )
                }
            }
        }
    }
    
    
    var researchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Research Results", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    browserModel.showResearchPanel = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            if let latestResearch = browserModel.researchResults.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(latestResearch.topic)
                            .font(.system(size: 18, weight: .bold))
                        
                        Text("Executive Summary")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(latestResearch.summary)
                            .font(.system(size: 12))
                        
                        Divider()
                        
                        Text("Key Findings")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                        
                        Text(latestResearch.keyFindings)
                            .font(.system(size: 12))
                        
                        if !latestResearch.sources.isEmpty {
                            Divider()
                            
                            Text("Sources")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.orange)
                            
                            ForEach(latestResearch.sources, id: \.self) { source in
                                Link(source, destination: URL(string: source)!)
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
        }
        .padding()
        .frame(width: 500)
        .glassCard()
        .draggableWindow()
        .offset(x: -20, y: 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    var agentPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            agentPanelHeader
            
            if browserModel.smartAgent.isRecording {
                recordingSection
            }
            
            if !browserModel.automationScripts.isEmpty && !browserModel.smartAgent.isRecording {
                savedAutomationsSection
            }
            
            if let latestAutomation = browserModel.automationResults.first {
                latestAutomationSection(latestAutomation)
            }
        }
        .padding()
        .frame(width: 500)
        .background(agentPanelBackground)
        .shadow(color: .orange.opacity(0.3), radius: 20)
        .offset(x: -20, y: 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    var agentPanelHeader: some View {
        HStack {
            Label("Automation Agent", systemImage: "gearshape.2.fill")
                .font(.system(size: 16, weight: .bold))
            
            Spacer()
            
            if browserModel.smartAgent.isExecuting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    
                    Text(browserModel.smartAgent.currentTask)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    
                    Text("\(Int(browserModel.smartAgent.taskProgress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            
            Button(action: {
                browserModel.showAgentPanel = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    var recordingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                
                Text("Recording Actions...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("\(browserModel.smartAgent.recordedActions.count) actions")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(browserModel.smartAgent.recordedActions) { action in
                        HStack {
                            Image(systemName: iconForActionType(action.type))
                                .font(.system(size: 10))
                                .foregroundColor(colorForActionType(action.type))
                                .frame(width: 20)
                            
                            Text(action.description)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 150)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
            
            HStack {
                Button("Stop Recording") {
                    Task {
                        await browserModel.stopRecording()
                    }
                }
                .buttonStyle(ActionButtonStyle())
                
                Button("Cancel") {
                    Task {
                        try? await browserModel.smartAgent.stopRecording()
                        browserModel.smartAgent.recordedActions.removeAll()
                    }
                }
                .foregroundColor(.red)
                .buttonStyle(ModernButtonStyle())
            }
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    var savedAutomationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved Automations")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(browserModel.automationScripts) { automation in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(automation.name)
                                    .font(.system(size: 12, weight: .medium))
                                
                                Text("\(automation.actions.count) actions")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button("Run") {
                                Task {
                                    await browserModel.executeAutomation(automation)
                                }
                            }
                            .font(.system(size: 11))
                            .buttonStyle(ModernButtonStyle())
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }
    
    func latestAutomationSection(_ automation: TaskAutomationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(automation.task)
                .font(.system(size: 14, weight: .medium))
            
            automationSteps(automation)
            
            if !browserModel.smartAgent.executionLog.isEmpty {
                executionLogSection
            }
            
            automationScriptSection(automation)
            
            automationActions(automation)
        }
    }
    
    func automationSteps(_ automation: TaskAutomationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Steps to Execute:")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
            
            ForEach(Array(automation.steps.prefix(5).enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Text(step)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if automation.steps.count > 5 {
                Text("... and \(automation.steps.count - 5) more steps")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
    
    var executionLogSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            
            Text("Execution Log")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(browserModel.smartAgent.executionLog, id: \.self) { log in
                        Text(log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
            }
            .frame(maxHeight: 100)
            .padding(6)
            .background(Color.black.opacity(0.3))
            .cornerRadius(4)
        }
    }
    
    func automationScriptSection(_ automation: TaskAutomationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            
            Text("Automation Script")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.green)
            
            ScrollView {
                Text(String(automation.automationScript.prefix(1000)))
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                
                if automation.automationScript.count > 1000 {
                    Text("... (truncated)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
        }
    }
    
    func automationActions(_ automation: TaskAutomationResult) -> some View {
        HStack {
            Button("Execute Now") {
                Task {
                    if let webView = browserModel.tabManager.activeTab?.webView {
                        try? await browserModel.smartAgent.executeAutomation(automation, on: webView)
                    }
                }
            }
            .buttonStyle(ActionButtonStyle())
            
            Button("Save") {
                let saved = BrowserViewModel.SavedAutomation(
                    name: "Automation \(Date().formatted())",
                    description: automation.task,
                    script: automation.automationScript,
                    actions: browserModel.smartAgent.recordedActions,
                    createdAt: Date()
                )
                browserModel.automationScripts.append(saved)
                browserModel.saveAutomations()
            }
            .buttonStyle(ModernButtonStyle())
            
            Button("Export") {
                // Export functionality
            }
            .buttonStyle(ModernButtonStyle())
        }
    }
    
    var agentPanelBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.95))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
    
    var workflowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Workflow Builder", systemImage: "flowchart")
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    browserModel.showWorkflowPanel = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            
            Text("Create automated workflows that run across multiple tabs and sites")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            // Workflow templates
            VStack(alignment: .leading, spacing: 8) {
                WorkflowTemplate(
                    name: "Price Comparison",
                    description: "Compare prices across multiple shopping sites",
                    icon: "cart.fill",
                    color: .green
                )
                
                WorkflowTemplate(
                    name: "Research Assistant",
                    description: "Gather information from multiple sources and compile report",
                    icon: "doc.text.magnifyingglass",
                    color: .blue
                )
                
                WorkflowTemplate(
                    name: "Form Auto-Fill",
                    description: "Automatically fill forms across multiple sites",
                    icon: "doc.text.fill",
                    color: .orange
                )
                
                WorkflowTemplate(
                    name: "Data Extraction",
                    description: "Extract and organize data from multiple pages",
                    icon: "square.and.arrow.down.fill",
                    color: .purple
                )
            }
            
            Button("Create Custom Workflow") {
                // Open workflow editor
            }
            .buttonStyle(ActionButtonStyle())
        }
        .padding()
        .frame(width: 400)
        .glassCard()
        .draggableWindow()
        .offset(x: -20, y: 140)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
    
    var statusBar: some View {
        HStack {
            if browserModel.smartAgent.isExecuting {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text(browserModel.smartAgent.currentTask)
                        .font(.system(size: 11))
                    
                    Spacer()
                    
                    Text("\(Int(browserModel.smartAgent.taskProgress * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                }
                .padding(.horizontal, 12)
            } else {
                Text("Ready")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Label("\(browserModel.tabManager.tabs.count)", systemImage: "square.stack")
                Label("\(browserModel.smartBookmarks.count)", systemImage: "bookmark.fill")
                Label("Gemini 2.5", systemImage: "cpu")
            }
            .font(.system(size: 10))
            .foregroundColor(.gray)
            .padding(.horizontal, 12)
        }
        .frame(height: 24)
        .background(Color.black.opacity(0.8))
    }
    
    func getAgentHelp(for action: String) -> String {
        switch action {
        case "research":
            return "Deep research with citations and analysis"
        case "automate":
            return browserModel.smartAgent.isRecording ? "Stop recording actions" : "Create and manage automations"
        case "record":
            return browserModel.smartAgent.isRecording ? "Stop recording browser actions" : "Record your actions to create automation"
        case "extract":
            return "Extract all structured data from page"
        case "analyze":
            return "Comprehensive page analysis and insights"
        case "workflow":
            return "Create multi-step automation workflows"
        default:
            return ""
        }
    }
}

// MARK: - Custom Views
struct AutomationListItem: View {
    let automation: BrowserViewModel.SavedAutomation
    let onExecute: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(automation.name)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(automation.description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        Label("\(automation.actions.count) actions", systemImage: "play.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text(automation.createdAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Button(action: onExecute) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(ModernButtonStyle())
                    
                    Menu {
                        Button("Edit") {
                            // Edit automation
                        }
                        
                        Button("Duplicate") {
                            // Duplicate automation
                        }
                        
                        Button("Export") {
                            // Export automation
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(ModernButtonStyle())
                }
            }
            
            // Action preview
            HStack(spacing: 8) {
                ForEach(automation.actions.prefix(5)) { action in
                    Image(systemName: iconForActionType(action.type))
                        .font(.system(size: 10))
                        .foregroundColor(colorForActionType(action.type))
                }
                
                if automation.actions.count > 5 {
                    Text("+\(automation.actions.count - 5)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    func iconForActionType(_ type: SmartAgent.AutomationAction.ActionType) -> String {
        switch type {
        case .click: return "cursorarrow.click"
        case .type: return "keyboard"
        case .select: return "list.bullet"
        case .navigate: return "arrow.right.circle"
        case .scroll: return "arrow.up.and.down"
        case .wait: return "clock"
        case .extract: return "doc.text.magnifyingglass"
        case .verify: return "checkmark.circle"
        }
    }
    
    func colorForActionType(_ type: SmartAgent.AutomationAction.ActionType) -> Color {
        switch type {
        case .click: return .blue
        case .type: return .green
        case .select: return .orange
        case .navigate: return .purple
        case .scroll: return .pink
        case .wait: return .yellow
        case .extract: return .cyan
        case .verify: return .mint
        }
    }
}

struct SmartTabView: View {
    let tab: AdvancedTabManager.SmartTab
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForPurpose(tab.purpose))
                .font(.system(size: 11))
                .foregroundColor(colorForPurpose(tab.purpose))
            
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: 150)
            
            if tab.automationEnabled {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
    
    func iconForPurpose(_ purpose: AdvancedTabManager.TabPurpose) -> String {
        switch purpose {
        case .general: return "globe"
        case .research: return "magnifyingglass"
        case .shopping: return "cart"
        case .work: return "briefcase"
        case .entertainment: return "play.circle"
        case .development: return "hammer"
        }
    }
    
    func colorForPurpose(_ purpose: AdvancedTabManager.TabPurpose) -> Color {
        switch purpose {
        case .general: return .gray
        case .research: return .blue
        case .shopping: return .green
        case .work: return .orange
        case .entertainment: return .pink
        case .development: return .purple
        }
    }
}

struct SidebarButton: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

struct WorkflowTemplate: View {
    let name: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Button Styles
struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - App Entry Point
@main
struct NexusAIBrowserApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserView()
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    // Handle in view
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}
EOAPP

# Create Info.plist
echo "Creating Info.plist..."
cat > Info.plist << 'EOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NexusAIBrowser</string>
    <key>CFBundleIdentifier</key>
    <string>com.nexusai.browser</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NexusAI Browser</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 NexusAI. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOPLIST

# Compile the application
echo -e "${PURPLE}Building Revolutionary Agentic Browser...${NC}"
echo "This is next-generation browser technology..."

# Create app bundle structure
APP_NAME="NexusAI Browser.app"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy Info.plist
cp Info.plist "$APP_NAME/Contents/"

# Build the executable
echo "Compiling advanced AI systems..."
if swiftc -o "$APP_NAME/Contents/MacOS/NexusAIBrowser" \
    NexusAIBrowser.swift \
    -framework SwiftUI \
    -framework WebKit \
    -framework Combine \
    -framework Vision \
    -framework NaturalLanguage \
    -framework CoreML \
    -target arm64-apple-macos13.0 \
    -parse-as-library \
    -O; then
    echo -e "${GREEN}✅ Build successful!${NC}"
else
    echo -e "${RED}Build failed. Trying alternative build...${NC}"
    
    # Simplified build without Vision/NaturalLanguage/CoreML
    if swiftc -o "$APP_NAME/Contents/MacOS/NexusAIBrowser" \
        NexusAIBrowser.swift \
        -framework SwiftUI \
        -framework WebKit \
        -framework Combine \
        -target arm64-apple-macos13.0 \
        -parse-as-library; then
        echo -e "${GREEN}✅ Build successful with core frameworks!${NC}"
    else
        echo -e "${RED}Build failed. Please ensure Xcode Command Line Tools are installed.${NC}"
        exit 1
    fi
fi

# Sign the app
echo "Signing the revolutionary browser..."
codesign --deep --force --sign - "$APP_NAME" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Could not sign the app.${NC}"
}

# Create DMG installer
echo "Creating installer package..."
DMG_NAME="NexusAI-Browser-Revolutionary.dmg"
rm -f "$DMG_NAME"

DMG_DIR="dmg_temp"
mkdir -p "$DMG_DIR"
cp -R "$APP_NAME" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications" 2>/dev/null || true

hdiutil create -volname "NexusAI Browser" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_NAME" 2>/dev/null || {
    echo -e "${YELLOW}Could not create DMG. App is ready in current directory.${NC}"
}

rm -rf "$DMG_DIR"

# Installation
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✨ REVOLUTIONARY AGENTIC BROWSER BUILD COMPLETE! ✨${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

read -p "Install NexusAI Browser to Applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if cp -R "$APP_NAME" "/Applications/" 2>/dev/null; then
        echo -e "${GREEN}✅ NexusAI Browser installed successfully!${NC}"
        INSTALL_PATH="/Applications/$APP_NAME"
    else
        cp -R "$APP_NAME" "$HOME/Desktop/"
        echo -e "${GREEN}✅ NexusAI Browser installed to Desktop!${NC}"
        INSTALL_PATH="$HOME/Desktop/$APP_NAME"
    fi
    
    echo ""
    read -p "🚀 Launch NexusAI Browser now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "$INSTALL_PATH"
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}🧠 NEXUSAI BROWSER - REVOLUTIONARY FEATURES${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}🎯 AUTONOMOUS AGENTS:${NC}"
echo "   • Research Agent - Multi-stage research with parallel execution"
echo "   • Automation Agent - Record, create, and execute browser automations"
echo "   • Data Extraction - Extract structured data as JSON with AI"
echo "   • Analysis Agent - Real-time page intelligence and insights"
echo "   • Workflow Builder - Create complex multi-step automations"
echo ""
echo -e "${YELLOW}🤖 REVOLUTIONARY AUTOMATION:${NC}"
echo "   • Action Recording - Record clicks, typing, and navigation"
echo "   • Smart Selector Generation - AI creates reliable CSS selectors"
echo "   • Multi-Format Export - Selenium, Playwright, or JavaScript"
echo "   • Visual Execution - Watch automations run in real-time"
echo "   • Error Recovery - Intelligent retry and fallback mechanisms"
echo "   • Parallel Execution - Run multiple automations simultaneously"
echo ""
echo -e "${YELLOW}🔮 SMART FEATURES:${NC}"
echo "   • AI-Powered Smart Bookmarks with auto-categorization"
echo "   • Intelligent Tab Grouping by purpose and content"
echo "   • Predictive Page Loading and Pre-fetching"
echo "   • Multi-Tab Content Synthesis and Correlation"
echo "   • Real-time Fact Checking and Verification"
echo "   • Natural Language Automation Commands"
echo ""
echo -e "${YELLOW}⚡ DATA INTELLIGENCE:${NC}"
echo "   • Structured Data Extraction (contacts, prices, dates)"
echo "   • Table and List Recognition with AI parsing"
echo "   • Entity Recognition (people, companies, products)"
echo "   • Cross-Site Data Aggregation and Analysis"
echo "   • Export to Multiple Formats (JSON, CSV, Excel)"
echo "   • Real-time Data Validation and Cleaning"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🚀 The future of browsing is here. Enjoy NexusAI Browser!${NC}"
echo ""
# ---------------------------------------------------------------------
# Optional secondary patch script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/install_nexus-new.sh" ]; then
    echo "🔄  Running additional patch script: install_nexus-new.sh"
    bash "$SCRIPT_DIR/install_nexus-new.sh"
fi
# ---------------------------------------------------------------------
