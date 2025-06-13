

#!/bin/bash
# Additional patch script for NexusAI Browser
# -------------------------------------------
# Any incremental patches that are too large or complex for the main
# install_nexus.sh can be placed here. The main installer will detect
# and execute this script automatically after completing its own tasks.

set -e

echo "🛠️  Running install_nexus-new.sh (additional patches)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$HOME/NexusAIBrowser"
SWIFT_FILE="$PROJECT_DIR/NexusAIBrowser.swift"

if [ ! -f "$SWIFT_FILE" ]; then
    echo "⚠️  Cannot find NexusAIBrowser.swift at $SWIFT_FILE"
    exit 1
fi

# ---------------------------------------------------------------------
# Example patch: Append a comment to the Swift file (placeholder)
# (Replace this block with real sed/awk edits or heredoc replacements.)
# ---------------------------------------------------------------------
echo "🔧  Applying example placeholder patch..."
printf "\n// Placeholder patch applied at $(date)\n" >> "$SWIFT_FILE"

# ---------------------------------------------------------------------
# Patch: Make AI panel body scrollable
# ---------------------------------------------------------------------
echo "🔧  Patching aiAssistantPanel to add ScrollView..."

# Use a simple perl in‑place edit: wrap the Text(...) line with ScrollView{ ... }
perl -0777 -i -pe '
    s/Text\\(browserModel\\.aiResponse\\.asMarkdownAttributed\\(\\)\\)([^\\n]*\\n[ \\t]*\\.font)/ScrollView{\\n            Text(browserModel.aiResponse.asMarkdownAttributed())/s
' "$SWIFT_FILE"

# Close the ScrollView by finding the line with .textSelection and inserting a closing brace
perl -0777 -i -pe '
    s/\\.textSelection\\([^\\)]*\\)/$&\\n        }/ if $. == 0' "$SWIFT_FILE"

echo "✅  AI panel is now scrollable."

echo "✅  Additional patches complete."

# ---------------------------------------------------------------------
# Patch: Collapsible sections in AI panel
# ---------------------------------------------------------------------
echo "🔧  Injecting collapsible-section support into aiAssistantPanel..."

# 1. Append String extension + collapsible view if not already present
grep -q "extension String \\{ // AI Section Split" "$SWIFT_FILE" || cat >> "$SWIFT_FILE" <<'SWIFTSNIP'

// ===== Collapsible Markdown Sections =====
extension String { // AI Section Split
    /// Splits markdown by "## Heading" into (title, body) tuples.
    func splitMarkdownSections() -> [(String, String)] {
        let pattern = #"(?m)^##[ \t]+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = self as NSString
        let matches = regex.matches(in: self, range: NSRange(location: 0, length: ns.length))
        var sections: [(String, String)] = []
        var lastIndex = self.startIndex
        for (i, match) in matches.enumerated() {
            let titleRange = Range(match.range(at: 1), in: self)!
            let title = String(self[titleRange])
            let start = titleRange.upperBound
            let end = i + 1 < matches.count ?
                Range(matches[i + 1].range, in: self)!.lowerBound : self.endIndex
            let body = String(self[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append((title, body))
        }
        // If no matches, return entire text as one section
        if sections.isEmpty { sections.append(("Response", self)) }
        return sections
    }
}

struct CollapsibleAIView: View {
    let markdown: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(markdown.splitMarkdownSections(), id: \.0) { title, body in
                    DisclosureGroup(
                        content: {
                            Text(body.asMarkdownAttributed())
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .padding(.top, 2)
                        },
                        label: {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    )
                    .padding(.vertical, 2)
                }
            }
            .padding()
        }
    }
}
// ===== End collapsible section helpers =====
SWIFTSNIP

# 2. Replace existing Text(...) line with CollapsibleAIView
perl -0777 -i -pe '
    s#Text\\(browserModel\\.aiResponse\\.asMarkdownAttributed\\(\\)\\)[^\\n]*(?:\\n[ \\t]*\\.font[^\n]*)##CollapsibleAIView(markdown: browserModel.aiResponse)#s
' "$SWIFT_FILE"

echo "✅  AI panel now uses collapsible DisclosureGroups."

# ---------------------------------------------------------------------
# Patch: Add .deepResearch case to WorkflowTemplate enum
# ---------------------------------------------------------------------
echo "🔧  Adding deepResearch case to WorkflowTemplate…"

perl -0777 -i -pe '
    s/enum WorkflowTemplate \{([^}]*)\}/enum WorkflowTemplate {\1    case deepResearch\n}/s
' "$SWIFT_FILE"

echo "✅  WorkflowTemplate now has .deepResearch."

# ---------------------------------------------------------------------
# Patch: Implement .deepResearch in runWorkflow
# ---------------------------------------------------------------------
echo "🔧  Extending runWorkflow(_:) to handle deepResearch…"

perl -0777 -i -pe '
    s/switch template \{([^}]*)\}/switch template {\1\n    case \\.deepResearch:\\n        Task { await performDeepResearch() }/s
' "$SWIFT_FILE"

# Inject performDeepResearch() helper if it does not exist
grep -q "func performDeepResearch()" "$SWIFT_FILE" || cat >> "$SWIFT_FILE" <<'SWIFT_FUNC'
    /// Runs a multi‑agent deep research workflow on the active tab title.
    func performDeepResearch() async {
        guard let topic = tabManager.activeTab?.title, !topic.isEmpty else { return }
        showAIPanel = true
        aiResponse = "🔍 Deep‑researching **\(topic)** …"

        do {
            async let history = geminiService.executeAgentTask(
                task: "Give a concise historical background of \(topic).",
                context: "",
                capability: .research)
            async let current = geminiService.executeAgentTask(
                task: "Summarize the current state of \(topic).",
                context: "",
                capability: .research)
            async let stats = geminiService.executeAgentTask(
                task: "Provide up‑to‑date statistics or data on \(topic).",
                context: "",
                capability: .dataAnalysis)

            let (h, c, s) = try await (history, current, stats)

            let summary = try await geminiService.executeAgentTask(
                task: """
                Synthesise a deep‑dive report on \(topic) covering:
                1. Historical context
                2. Current landscape
                3. Key statistics
                4. Emerging trends
                5. Actionable insights
                """,
                context: [h, c, s].joined(separator: "\n\n"),
                capability: .contentCreation)

            aiResponse = "## Executive Summary\n\(summary)"
        } catch {
            aiResponse = "⚠️ Deep research failed: \(error.localizedDescription)"
        }
    }
SWIFT_FUNC

echo "✅  runWorkflow extended and helper inserted."

# ---------------------------------------------------------------------
# Patch: Add Deep Research card to workflowPanel UI
# ---------------------------------------------------------------------
echo "🔧  Inserting Deep Research card into workflowPanel…"

perl -0777 -i -pe '
    s/WorkflowTemplateCard\(icon: "tray\.and\.arrow\.down"[\s\S]*?\.buttonStyle\(\.plain\)/$&\n\n            Button(action: { Task { await browserModel.runWorkflow(.deepResearch) } }) {\n                WorkflowTemplateCard(icon: "book.closed",\n                                     title: "Deep Research",\n                                     subtitle: "Parallel + sequential AI deep-dive",\n                                     color: .pink)\n            }\n            .buttonStyle(.plain)/s
' "$SWIFT_FILE"

echo "✅  Deep Research card added."
#
# ---------------------------------------------------------------------
# Patch: Enhance YouTube right‑click with custom overlay
# ---------------------------------------------------------------------
echo "🔧  Enhancing YouTube context‑menu JS…"

perl -0777 -i -pe '
    s/document\.addEventListener\('"'"'contextmenu'"'"', function\([^}]+?ytContext\.postMessage[^;]+;//s/document.addEventListener('"'"'contextmenu'"'"', function(e) {\n  const link = e.target.closest('"'"'a[href*=\\"youtube.com\\/watch\\"]'"'"');\n  if (!link) { return; }\n  e.preventDefault();\n  // Build a simple custom menu\n  const menu = document.createElement("div");\n  menu.textContent = "🎥 Summarize with Gemini";\n  menu.style.position = "fixed";\n  menu.style.zIndex = 999999;\n  menu.style.left = e.pageX + "px";\n  menu.style.top  = e.pageY + "px";\n  menu.style.padding = "6px 10px";\n  menu.style.background = "rgba(0,0,0,0.8)";\n  menu.style.color = "#fff";\n  menu.style.fontSize = "12px";\n  menu.style.borderRadius = "6px";\n  menu.style.cursor = "pointer";\n  document.body.appendChild(menu);\n  const removeMenu = () => menu.remove();\n  menu.addEventListener("click", () => {\n    window.webkit.messageHandlers.ytContext.postMessage(link.href);\n    removeMenu();\n  });\n  setTimeout(removeMenu, 4000);\n}, true);/s
' "$SWIFT_FILE"

echo "✅  YouTube right‑click now shows 'Summarize with Gemini' overlay."

# ---------------------------------------------------------------------
# Patch: Ensure performDeepResearch() resides in BrowserViewModel scope
# ---------------------------------------------------------------------
echo "🔧  Verifying performDeepResearch() location…"

if ! grep -q "extension BrowserViewModel" "$SWIFT_FILE"; then
  echo "ℹ️  Adding BrowserViewModel extension with performDeepResearch()"
  cat >> "$SWIFT_FILE" <<'SWIFT_EXT'

extension BrowserViewModel {
    /// Runs a multi‑agent deep research workflow on the active tab title.
    func performDeepResearch() async {
        guard let topic = tabManager.activeTab?.title, !topic.isEmpty else { return }
        showAIPanel = true
        aiResponse = "🔍 Deep‑researching **\(topic)** …"

        do {
            async let history = geminiService.executeAgentTask(
                task: "Give a concise historical background of \(topic).",
                context: "",
                capability: .research)
            async let current = geminiService.executeAgentTask(
                task: "Summarize the current state of \(topic).",
                context: "",
                capability: .research)
            async let stats = geminiService.executeAgentTask(
                task: "Provide up‑to‑date statistics or data on \(topic).",
                context: "",
                capability: .dataAnalysis)

            let (h, c, s) = try await (history, current, stats)

            let summary = try await geminiService.executeAgentTask(
                task: """
                Synthesise a deep‑dive report on \(topic) covering:
                1. Historical context
                2. Current landscape
                3. Key statistics
                4. Emerging trends
                5. Actionable insights
                """,
                context: [h, c, s].joined(separator: "\n\n"),
                capability: .contentCreation)

            aiResponse = "## Executive Summary\n\(summary)"
        } catch {
            aiResponse = "⚠️ Deep research failed: \(error.localizedDescription)"
        }
    }
}
SWIFT_EXT
else
  echo "✔️  BrowserViewModel extension already present."
fi
echo "✅  performDeepResearch() is now within BrowserViewModel."

# ---------------------------------------------------------------------
# Patch: Ensure summarizeYouTube() and createCustomWorkflow() exist at type scope
# ---------------------------------------------------------------------
echo "🔧  Verifying summarizeYouTube() and createCustomWorkflow() existence…"

ensure_method() {
  local signature="$1"
  local body="$2"
  if ! grep -q "$signature" "$SWIFT_FILE"; then
    echo "ℹ️  Adding $signature to BrowserViewModel"
    cat >> "$SWIFT_FILE" <<SWIFT_SNIPPET

extension BrowserViewModel {
$body
}
SWIFT_SNIPPET
  else
    echo "✔️  $signature already present."
  fi
}

ensure_method "func summarizeYouTube(urlString: String)" '
    /// Summarize a YouTube link (used by right‑click)
    func summarizeYouTube(urlString: String) async {
        guard urlString.contains("youtube.com/watch") else { return }
        showAIPanel = true
        aiResponse = "⏳ Summarizing selected video…"
        do {
            let summary = try await geminiService.executeAgentTask(
                task: """
                Summarize the YouTube video at: \(urlString)
                • Fetch transcript
                • Provide timestamps and 3‑5 key insights
                """,
                context: "",
                capability: .contentExtraction)
            aiResponse = summary
        } catch {
            aiResponse = "⚠️ Summarization failed: \\(error.localizedDescription)"
        }
    }

    /// Summarize the currently open YouTube video tab.
    func summarizeYouTube() async {
        guard let urlString = tabManager.activeTab?.url,
              urlString.contains("youtube.com/watch") else {
            aiResponse = "🎬 Please open a YouTube video first."
            showAIPanel = true
            return
        }
        await summarizeYouTube(urlString: urlString)
    }'

ensure_method "func createCustomWorkflow(from prompt: String)" '
    /// Uses Gemini to turn a natural‑language prompt into a structured workflow.
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
                {\\"action\\": \\"verb\\", \\"parameters\\": {...}}
                Respond only with JSON.
                Request: \\(trimmed)
                """,
                context: "",
                capability: .taskAutomation)

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
                triggers: [])

            tabManager.workflows.append(workflow)
            aiResponse = "✅ Workflow created with \\(steps.count) steps."
        } catch {
            aiResponse = "⚠️ Failed to create workflow: \\(error.localizedDescription)"
        }
    }'

echo "✅  BrowserViewModel methods verified."

# ---------------------------------------------------------------------
# Patch: Enable Web Inspector (developerExtrasEnabled)
# ---------------------------------------------------------------------
echo "🔧  Enabling Web Inspector on WKWebView..."

perl -0777 -i -pe '
    s/let config = WKWebViewConfiguration\\(\\)/&\
            // Enable Web Inspector for debugging\
            config.preferences.setValue(true, forKey: "developerExtrasEnabled")/s
' "$SWIFT_FILE"

echo "✅  Web Inspector enabled."

# ---------------------------------------------------------------------
# Patch: Instrument summarizeYouTube() for URL debug
# ---------------------------------------------------------------------
echo "🔧  Instrumenting summarizeYouTube() with debug logs..."

perl -0777 -i -pe '
    s/(func summarizeYouTube\\(\\) async \\{)/\1\
        // DEBUG: capture current URL\
        let debugURL = tabManager.activeTab?.url ?? "nil"\
        print("⚙️ Debug summarizeYouTube URL:", debugURL)\
        aiResponse = "🔍 Debug URL: \\(debugURL)"/
' "$SWIFT_FILE"

echo "✅  summarizeYouTube() debug instrumentation added."