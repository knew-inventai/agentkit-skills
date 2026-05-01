---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy.
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

At a high level, the process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate the results both qualitatively and quantitatively
- Rewrite the skill based on feedback
- Repeat until satisfied

## Capture Intent

Start by understanding the user's intent. The current conversation might already contain a workflow the user wants to capture.

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases to verify the skill works?

## Interview and Research

Proactively ask questions about edge cases, input/output formats, example files, success criteria, and dependencies.

## Write the SKILL.md

Based on the user interview, fill in these components:

- **name**: Skill identifier
- **description**: When to trigger, what it does. Include both what the skill does AND specific contexts for when to use it. Make descriptions slightly "pushy" to avoid undertriggering.
- **the rest of the skill**

### Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

### Progressive Disclosure

Skills use a three-level loading system:
1. **Metadata** (name + description) — Always in context (~100 words)
2. **SKILL.md body** — In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** — As needed (unlimited)

### Writing Patterns

**Defining output formats:**
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern:**
```markdown
## Commit message format
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Writing Style

- Explain *why* things are important, don't just mandate with MUST/NEVER
- Use theory of mind — make the skill general, not narrow to specific examples
- Prefer imperative form in instructions

## Test Cases

After writing the skill draft, come up with 2–3 realistic test prompts. Then run them and evaluate the results.

Save test cases to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result"
    }
  ]
}
```

## Description Optimization

The description field in SKILL.md frontmatter is the primary triggering mechanism. After creating a skill, optimize the description for better triggering accuracy:

1. Generate 20 eval queries (mix of should-trigger and should-not-trigger)
2. Review with user
3. Run optimization loop
4. Apply the best description

### How skill triggering works

Skills appear in Claude's `available_skills` list with their name + description. Claude decides whether to consult a skill based on that description. Complex, multi-step, or specialized queries reliably trigger skills when the description matches.

## The core loop

1. Figure out what the skill is about
2. Draft or edit the skill
3. Run claude-with-access-to-the-skill on test prompts
4. Evaluate outputs with the user
5. Repeat until satisfied

> Source: [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
