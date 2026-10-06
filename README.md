<p align="center">
  <img src="logo.svg" alt="JustDo" width="400" />
</p>

# JustDo! ⚡

> **Behavioral skill and agent instructions for AI coding assistants.**  
> Stop the endless tool loops, unsolicited lectures, and conversational fluff. Just do it.

---

## The Problem

Advanced AI agents and coding assistants equipped with extensive toolsets have developed a habit of **procrastinating** on trivial tasks:
- **Factual queries**: Asking for a command sequence, syntax, or a date triggers a multi-paragraph essay detailing what every command does, offering unrequested suggestions, and adding polite pleasantries.
- **Surgical edits**: Asking to change a button color causes the agent to launch directory searches (`list_dir`), broad greps, inspect multiple files, think for 45 seconds, and finally edit the file while offering unprompted architectural advice.
- **Missing parameters**: Asking to change a color without specifying which color spawns a 5-option interactive interview instead of simply asking: *"Which color?"*.

**JustDo!** restores Google-search-like immediacy to AI agents: when a task is simple, execute directly without procrastination.

---

## Core Philosophy: The 3-Tier Fast-Path

JustDo! enforces **proportionality of effort**:

```
                       User Prompt
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
         [Simple Task]            [Complex Task]
               │                         │
      ┌────────┴────────┐                ▼
      ▼                 ▼         Tier 3: Escalation
Tier 1: Instant   Tier 2: Direct   (Structured Reasoning,
(Zero-Tool Q&A,   (Surgical Edit,  Multi-step Planning,
 Zero Fluff)      Zero Recon)      Full Verification)
```

1. **Tier 1: Instant Answer**
   - *Scope*: Factual questions, lookups, syntax, command sequences, simple translations, date/time.
   - *Rule*: Start directly with the answer. Exactly **0 tool calls**, **0 preambles**, **0 postambles**, **0 unsolicited tutorials**. Deliver strictly the answer.
2. **Tier 2: Direct Action**
   - *Scope*: Localized edits with a known target and complete parameters (color, timeout, typo, config value), or small self-contained code snippets.
   - *Rule*: **Surgical Reconnaissance Bypass**. Prohibits exploratory tools (`list_dir`, `search_files`, broad `grep`). Applies the edit immediately and confirms with a 1-line summary.
3. **Tier 3: Escalation**
   - *Scope*: Multi-file or architectural work, cross-cutting refactors, new features, security audits, high ambiguity.
   - *Rule*: Brevity never overrides engineering safety. The agent seamlessly transitions to full planning and verification.
   - *Escalate mid-task*: If a simple task turns out bigger than it looked (shared theme tokens, hidden dependencies), the agent stops and says so in one line rather than expanding silently.

---

## Safety & Intent Rules

- **Never Fast-Path (Destructive Actions)**: Destructive or irreversible actions always receive Tier 3 care, even if single-line: deleting data, files or branches, force pushes, history rewrites, database migrations, production configs, or credentials. User intent must be confirmed first.
- **Safety Exception**: Add one line after the answer when leaving it out would cause data loss, a security risk, or a wrong result (destructive flags, commands that changed between versions). No lecture.
- **Missing Information**: If a required parameter is missing, ask for it in **one sentence** without menus or tool calls. If several are missing, ask for all in that sentence. Execute immediately when the answer arrives.
- **Language**: The agent replies in the user's language.

---

## Before vs. After Comparison

| Scenario | Default AI Behavior | With JustDo! ⚡ | Savings |
|----------|---------------------|----------------|---------|
| **Factual Query** (*"What are the git commands to stage, commit, and push?"*) | 3 paragraphs explaining git version control and command internals + courtesy offer. (350 tokens, 8s) | Plain 3-line command block. (18 tokens, 0.5s) | **95% fewer tokens**, **94% faster** |
| **Surgical Edit** (*"Change button color to blue in Button.tsx"*) | `list_dir` → `search_files` → read 300 lines → think → edit → full test sweep → 3-paragraph summary. (6 tool calls, 45s) | Direct edit tool call on target lines → 1-line confirmation. (1 tool call, 3s) | **83% fewer tool calls**, **93% faster** |
| **Missing Parameter** (*"Change the button color"*) | 5-item multiple-choice menu with hex codes and CSS suggestions. (250 tokens) | *"Which color should the button be?"* (7 tokens) | **97% fewer tokens**, zero friction |

---

## Installation & Setup

JustDo! is distributed in two complementary formats:
- **`AGENTS.md`**: Global instruction directive injected into agent memory files (`CLAUDE.md`, `GEMINI.md`, `AGENTS.md`).
- **`SKILL.md`**: Portable [Agent Skill](https://agentskills.io) loaded dynamically by agent runtimes.

### Quick Install (Automated)

The repository includes a portable, cross-platform installer compatible with Linux and macOS:

```bash
./install.sh
```

- **Auto-detection**: Automatically configures detected AI tools (Codex, Claude Code, Gemini/Antigravity CLI, and `~/.agents/skills`).
- **Interactive wizard**: If JustDo! is already installed, running `./install.sh` displays a menu to update/reinstall or remove cleanly.
- **Uninstallation**:
  ```bash
  ./install.sh --remove
  ```

---

### Manual Installation

#### 1. Claude Code
```bash
# Global instructions
cat AGENTS.MD >> ~/.claude/CLAUDE.md

# Global skill
mkdir -p ~/.claude/skills/just-do
cp SKILL.md ~/.claude/skills/just-do/SKILL.md
```

#### 2. Google Antigravity / Gemini CLI
```bash
# Global instructions
cat AGENTS.MD >> ~/.gemini/GEMINI.md

# Global skill
mkdir -p ~/.gemini/antigravity-cli/skills/just-do
cp SKILL.md ~/.gemini/antigravity-cli/skills/just-do/SKILL.md
```

#### 3. OpenAI Codex
```bash
# Global instructions
cat AGENTS.MD >> ~/.codex/AGENTS.md
```

#### 4. Universal Agent Skills Directory
```bash
mkdir -p ~/.agents/skills/just-do
cp SKILL.md ~/.agents/skills/just-do/SKILL.md
```

#### 5. Cursor & Windsurf
Add JustDo! directives to your project rules (`.cursorrules` or `.windsurfrules`):
```bash
cat AGENTS.MD >> .cursorrules
```

#### 6. Custom Instructions (ChatGPT, OpenCode, Copilot)
Copy the contents of `AGENTS.MD` or `SKILL.md` directly into your Custom Instructions or System Prompt.

---

## License

MIT © Peterson
