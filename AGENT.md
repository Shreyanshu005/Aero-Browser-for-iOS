# AGENT.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it; don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```text
1. [Step]  verify: [check]
2. [Step]  verify: [check]
3. [Step]  verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Aero Project Rules

- Work only in your assigned worktree and branch.
- Read the relevant existing files before planning.
- First provide a short plan with assumptions, files likely to change, and validation checks.
- Wait for manager approval before implementation unless explicitly told to proceed directly.
- Keep feature work modular under the relevant `Aero/Features/...` area whenever possible.
- Reuse existing Aero design components, theme helpers, view models, and navigation patterns before adding new ones.
- Do not rename or reorganize unrelated files.
- Do not include AI, assistant, Codex, or agent branding in commit messages.
- Commit only your assigned feature.
- Do not revert work made by other branches or users.

## 6. Agentic Browser MVP Rules

- SwiftyAI should provide the AI/tool loop, not direct WebKit control by itself.
- Browser automation should go through typed tools such as observe page, open URL, click, type, press key, scroll, wait, extract data, ask approval, and finish.
- Tools must be small, inspectable, and easy to mock.
- Actions that post, purchase, log in, delete, upload, download, or share private data must require explicit user approval.
- Prefer visible-page observation and stable element IDs over brittle coordinate-only automation.
- Keep BYOK credentials in secure storage, not plain user defaults.

## 7. Required Validation

Run the checks that are available in your environment:

```powershell
git diff --check
git diff --cached --check
rg -n "^(<<<<<<<|=======|>>>>>>>)" Aero AeroTests AeroUITests AGENT.md
```

If `swift` or `xcodebuild` is unavailable, say so in your final note instead of pretending the build passed.

These guidelines are working if there are fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
