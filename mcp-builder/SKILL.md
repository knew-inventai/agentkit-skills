---
name: mcp-builder
description: Guide for creating high-quality MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. Use when building MCP servers to integrate external APIs or services, whether in Python (FastMCP) or Node/TypeScript (MCP SDK).
---

# MCP Server Development Guide

Create MCP (Model Context Protocol) servers that enable LLMs to interact with external services through well-designed tools. The quality of an MCP server is measured by how well it enables LLMs to accomplish real-world tasks.

---

## Phase 1: Deep Research and Planning

### Understand Modern MCP Design

**API Coverage vs. Workflow Tools:**
Balance comprehensive API endpoint coverage with specialized workflow tools. When uncertain, prioritize comprehensive API coverage.

**Tool Naming and Discoverability:**
Use consistent prefixes (e.g., `github_create_issue`, `github_list_repos`) and action-oriented naming.

**Actionable Error Messages:**
Error messages should guide agents toward solutions with specific suggestions and next steps.

### Recommended Stack

- **Language**: TypeScript (high-quality SDK support, good compatibility, broadly used)
- **Transport**: Streamable HTTP for remote servers (stateless JSON); stdio for local servers

### Fetch Framework Documentation

- **TypeScript SDK**: `https://raw.githubusercontent.com/modelcontextprotocol/typescript-sdk/main/README.md`
- **Python SDK**: `https://raw.githubusercontent.com/modelcontextprotocol/python-sdk/main/README.md`
- **MCP Spec**: `https://modelcontextprotocol.io/sitemap.xml` then fetch relevant pages with `.md` suffix

---

## Phase 2: Implementation

### Project Structure (TypeScript)

```
my-mcp-server/
├── src/
│   ├── index.ts        # Entry point, server setup
│   ├── tools/          # Tool implementations
│   └── utils/          # Shared helpers (auth, errors, pagination)
├── package.json
└── tsconfig.json
```

### Implement Tools

For each tool:

**Input Schema (Zod):**
```typescript
const MyToolInput = z.object({
  query: z.string().describe("Search query"),
  limit: z.number().min(1).max(100).default(20).describe("Max results"),
});
```

**Tool Registration:**
```typescript
server.registerTool("search_items", {
  description: "Search for items matching a query",
  inputSchema: MyToolInput,
  annotations: { readOnlyHint: true },
}, async (input) => {
  const results = await apiClient.search(input.query, input.limit);
  return {
    content: [{ type: "text", text: JSON.stringify(results, null, 2) }],
    structuredContent: results,
  };
});
```

**Tool Annotations:**
- `readOnlyHint`: true/false
- `destructiveHint`: true/false
- `idempotentHint`: true/false
- `openWorldHint`: true/false

### Error Handling

```typescript
try {
  const result = await apiCall();
  return { content: [{ type: "text", text: JSON.stringify(result) }] };
} catch (error) {
  throw new McpError(
    ErrorCode.InternalError,
    `Failed to fetch data: ${error.message}. Check your API token and try again.`
  );
}
```

---

## Phase 3: Review and Test

```bash
# TypeScript build
npm run build

# Test with MCP Inspector
npx @modelcontextprotocol/inspector

# Python syntax check
python -m py_compile your_server.py
```

Code quality checklist:
- [ ] No duplicated code
- [ ] Consistent error handling
- [ ] Full type coverage
- [ ] Clear tool descriptions
- [ ] Pagination support where applicable

---

## Phase 4: Create Evaluations

Create 10 evaluation questions to test whether LLMs can effectively use your MCP server:

- **Independent**: Not dependent on other questions
- **Read-only**: Only non-destructive operations
- **Complex**: Requiring multiple tool calls
- **Verifiable**: Single, clear answer

```xml
<evaluation>
  <qa_pair>
    <question>How many open issues are labeled 'bug' in the repository?</question>
    <answer>42</answer>
  </qa_pair>
</evaluation>
```

---

## mcp-config.json format (for Claude Code / Cursor)

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-mcp-package"],
      "env": {
        "API_TOKEN": "${MY_API_TOKEN}"
      }
    }
  }
}
```

> Source: [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/mcp-builder)
