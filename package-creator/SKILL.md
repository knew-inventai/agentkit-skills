______________________________________________________________________

## name: package-creator description: Package existing content into AgentKit-compatible format (plugin.json + main file + README) ready for PR submission. Use when a user wants to manually submit a PR to AgentKit, has an existing skill/prompt/MCP config/plugin and needs it packaged correctly, or is unsure how to structure their AgentKit package.

# AgentKit Package Creator

Guide the user through packaging their content into the exact file structure AgentKit expects, producing files ready to submit as a Pull Request.

## Step 1: Identify the Package Type

Ask the user what they want to publish:

- **Skill** — A `SKILL.md` with AI behavior instructions or workflow
- **Prompt** — A `PROMPT.md` with a reusable prompt template
- **MCP Server** — A `mcp-config.json` with server connection settings
- **Plugin** — A `plugin.json` with slash command definitions

If they already have content, ask them to share it so you can determine the type automatically.

## Step 2: Gather Metadata

Ask for (or infer from their content):

1. **Name** — Unique identifier, `kebab-case`, lowercase, no spaces (e.g. `my-code-reviewer`)
1. **Description** — One sentence, under 100 characters
1. **Author** — GitHub username or name
1. **Tags** — 2–5 comma-separated keywords (e.g. `review, typescript, security`)
1. **Compatible platforms** — Which AI platforms it supports: `claude`, `openai`, `gemini` (default: `claude`)
1. **Version** — Start with `1.0.0` unless updating an existing package

If any field is unclear, suggest a reasonable default and ask for confirmation rather than blocking.

## Step 3: Generate the Files

Produce all required files based on the type. Show each file in a clearly labeled code block.

### For a Skill

**`plugin.json`**

```json
{
  "name": "<name>",
  "version": "<version>",
  "description": "<description>",
  "author": { "name": "<author>", "email": "<email-if-provided>" },
  "license": "MIT",
  "_agentkit": {
    "type": "skill",
    "tags": [<tags>],
    "compatible": [<compatible>]
  }
}
```

**`SKILL.md`** — Use or refine the user's existing content. Structure it with:

- A YAML frontmatter block (`name`, `description`)
- Clear step-by-step instructions in imperative form
- Explain the *why* behind each step, not just the *what*
- Keep under 500 lines

**`README.md`** (recommended)

- Installation command: `/plugin install <name>@agentkit-skills`
- 2–3 sentence description
- Example trigger phrases
- Any prerequisites

______________________________________________________________________

### For a Prompt

**`plugin.json`** — Same structure as Skill, with `"type": "prompt"`

**`PROMPT.md`** — Use or refine the user's content. A prompt template should be:

- Self-contained (no external references needed to use it)
- Clear about when/how to apply it
- Include usage examples if relevant

**`README.md`** (recommended)

- How to apply the prompt (paste into CLAUDE.md, system prompt, etc.)
- What behavior it produces

______________________________________________________________________

### For an MCP Server

**`plugin.json`** — Same structure, with `"type": "mcp"`

**`mcp-config.json`** — Validate and format as:

```json
{
  "mcpServers": {
    "<server-name>": {
      "command": "npx",
      "args": ["-y", "<package-name>"],
      "env": {
        "<ENV_VAR>": "<description-or-placeholder>"
      }
    }
  }
}
```

For HTTP-based MCP servers:

```json
{
  "mcpServers": {
    "<server-name>": {
      "type": "http",
      "url": "<url>",
      "headers": {
        "Authorization": "Bearer ${TOKEN_ENV_VAR}"
      }
    }
  }
}
```

**`README.md`** (recommended)

- How to set required environment variables / tokens
- List of available tools/capabilities
- Where to obtain credentials

______________________________________________________________________

### For a Plugin

**`plugin.json`** — Include manifest fields plus `commands` array:

```json
{
  "name": "<name>",
  "version": "<version>",
  "description": "<description>",
  "author": { "name": "<author>" },
  "license": "MIT",
  "_agentkit": {
    "type": "plugin",
    "tags": [<tags>],
    "compatible": ["claude"]
  },
  "commands": [
    {
      "name": "<command-name>",
      "description": "<what this command does>",
      "prompt": "<the full instruction prompt Claude will follow>"
    }
  ]
}
```

**`README.md`** (recommended)

- Installation command: `/plugin install <name>@agentkit-plugins`
- List of available slash commands with descriptions
- Usage examples

______________________________________________________________________

## Step 4: Validate

Before presenting the final output, check:

- [ ] `name` matches the intended directory name exactly
- [ ] `name` is lowercase `kebab-case` with no special characters except `-`
- [ ] `description` is under 100 characters
- [ ] `_agentkit.type` matches the actual content type
- [ ] Main file content is present and non-empty
- [ ] `mcp-config.json` uses the correct `mcpServers` top-level key (not `servers` or `mcp`)
- [ ] Sensitive values use `${ENV_VAR}` placeholders, not real tokens

## Step 5: Present the Final Package

Show the complete directory structure:

```
<name>/
├── plugin.json
├── <SKILL.md | PROMPT.md | mcp-config.json>   ← main file
└── README.md
```

Then show each file's full content in labeled code blocks, ready to copy.

Finally, give the PR submission instructions:

```
Target repository: knew-inventai/agentkit-<skills|prompts|mcp|plugins>
Branch name:       add/<name>
PR title:          feat: add <name> v<version>
PR body:           ## <name>\n\n<description>\n\nType: <type> | Tags: <tags>
```

## Tips

- If the user's content is rough or incomplete, help them improve it — a better skill/prompt is more useful to everyone.
- If they're unsure about tags, suggest based on the content you see.
- For MCP configs, check if the package exists on npm and suggest the correct `npx` invocation.
- Don't ask for information you can reasonably infer — minimize friction.
