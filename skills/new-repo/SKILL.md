---
name: new-repo
description: Scaffold the Claude Code setup for a repository — CLAUDE.md, .claude/settings.json, .mcp.json and the docs skeleton. Use when starting a new repo, or when bringing an existing repo up to the standard layout.
---

# New repo

Run this **before anything else** in a repo that has no setup yet, or to bring an existing one up to standard.

## The rule this whole template obeys

> **The repo says what is true about this product. Nothing else.**

Working process, tone, git conventions and approval gates live in `~/.claude/`. They load automatically from any repo. **Never duplicate them here** — duplication is how the two versions drift apart and start contradicting each other.

If a line would be equally true in a repo that doesn't exist yet, it does not belong in this file.

## Ask first

1. **What is this product, in one line?** Who uses it.
2. **Stack** — runtime, framework, database.
3. **Commands** — dev, build, test, typecheck, lint.
4. **Deploy** — where it runs, how it gets there, is there staging.
5. **Does it take payments?** (decides whether `docs/pagos/` exists)
6. **Which MCP servers does it need?** (see `~/.claude/CLAUDE.md` for the global ones)

Do not guess any of these. Read `package.json`, `pyproject.toml`, `.github/workflows/` and the existing code first, then ask about what you could not find.

## What to create

```
<repo>/
├── CLAUDE.md              this product only
├── README.md              for humans, not for Claude
├── .mcp.json              AT THE ROOT. Only if it needs repo-scoped servers
├── .claude/
│   └── settings.json      typecheck hook only
└── docs/
    ├── GUIDEBOOK.md       how to contribute
    ├── HANDBOOK.md        infra and deploy reference
    ├── arquitectura/
    ├── operaciones/
    ├── planes/
    ├── seguridad/
    └── pagos/             only if it bills
```

### The full anatomy of `.claude/`

Create the whole tree, even the folders you will not fill on day one. The
structure teaches: it shows where things go before you need to know. Each empty
folder carries a one-line `README.md` — git cannot track an empty directory, and
the note explains itself to whoever opens it next.

| Path | What goes there | Add it when |
|---|---|---|
| `.claude/settings.json` | Permissions and hooks for this repo | **Day one** — the typecheck hook |
| `.claude/rules/*.md` | Instructions scoped to part of the tree, via `paths:` frontmatter | Created empty. Fill when the root CLAUDE.md passes ~200 lines, or a rule only applies to one folder |
| `.claude/skills/<name>/SKILL.md` | Procedures specific to this product | Created empty. Fill when there's a repeatable multi-step job here |
| `.claude/agents/<name>.md` | Subagents for this domain | Created empty. Fill when a global agent isn't specific enough |
| `.claude/settings.local.json` | Your personal overrides | Never committed. Auto-gitignored |
| `.claude/agent-memory/` | Written by an agent with `memory: project` | Never by hand |

`rules/` is the pressure valve for a CLAUDE.md that grows. A rule with
`paths: ["panels/**"]` only enters context when Claude touches that folder,
so the cost is paid where it's useful instead of in every session.

### `.mcp.json` goes at the root, not in `.claude/`

Inside `.claude/` it does not load and gives no warning. This is the single most
common silent failure in a repo setup.

### Not part of the template

`.worktreeinclude` copies gitignored files into new worktrees, but it is **only
read when Claude Code creates the worktree** (`--worktree`, the `EnterWorktree`
tool, or a subagent with `isolation: worktree`). A worktree created by hand with
`git worktree add` ignores it. Add it only if that changes.

`template/` next to this file mirrors that tree exactly. Copy it into the repo, then fill it in — never leave a placeholder in place.

```
template/
├── CLAUDE.md
├── README.md
├── .mcp.json
├── .claude/settings.json
└── docs/{GUIDEBOOK.md, HANDBOOK.md}
```

### `CLAUDE.md`

Target under 200 lines. Sections, in order:

| Section | Contents |
|---|---|
| One-liner | What it is, who uses it |
| Stack | Runtime, framework, database, hosting |
| Commands | dev · build · test · typecheck · deploy. Exact, copy-pasteable |
| Layout | Which folder does what. Only where it isn't obvious |
| Tools | CLIs available and the MCP servers declared. **With the traps** |
| Traps | The things that cost hours and are in no `--help` |
| Docs | Pointers to GUIDEBOOK, HANDBOOK, `arquitectura/` |

The **Traps** section is the one that earns its place. Everything else can be re-derived from the code; that cannot.

### `.claude/settings.json`

One hook, nothing else. Branch protection is global.

```json
{
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "<the repo's typecheck command>" }] }
    ]
  }
}
```

Use the real command for the stack: `npx tsc --noEmit`, `pyright`, `cargo check`, `go vet`.

### `.mcp.json`

**At the repository root, not inside `.claude/`.** Inside `.claude/` it does not load and gives no warning.

Only servers this repo actually uses. If a CLI does the job, prefer the CLI — it costs nothing at startup and its auth does not expire.

## Do not create

- `hooks/` with branch-protection scripts — that lives in `~/.claude/`
- A copy of the global working process or approval gates
- `docs/pagos/` if the repo does not bill — delete that one
- Placeholders left unfilled. Every `<...>` must be replaced or the line removed

## Finally

Ask whether to `git add` the new files. Do not commit without being asked.
