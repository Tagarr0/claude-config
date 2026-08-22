# LLM agents

How to build an agent **inside a product**. This is not about Claude Code subagents — it is about shipping an agent to users.

Framework-agnostic on purpose. LangGraph, an SDK, or a hand-rolled loop all fit this shape; picking one is a separate decision.

## The layering

```
Agent            the prompt: role, policy, what it is allowed to decide
   ↓  contract   tool names, descriptions and schemas — this IS part of the prompt
Tools            deterministic. Validate, execute, return a typed result
   ↓
APIs             yours, versioned. The agent never touches a third party directly
   ↓
Software         database, queues, external services
```

Each layer only talks to the one below it. Skipping a layer is where agents rot.

### Why the contract is a layer and not a detail

The model picks a tool by reading its **name and description**. Those are prompt, not plumbing. A vague description is a vague prompt.

```
✗ update_record(id, data)          "Updates a record"
✓ reschedule_booking(booking_id, new_start_utc)
  "Move an existing booking to a new time. Fails if the slot is taken.
   Does not create bookings — use create_booking for that."
```

The second one tells the model when *not* to reach for it. That is what stops wrong calls.

Rules:
- Few tools, sharply named. Ten focused beats forty generic
- The schema is the validation. If a field can be wrong, make it an enum
- Return typed results, including typed failures — `{ok: false, reason: "slot_taken"}` beats a thrown error the model has to interpret
- The description says what it does **and what it does not**

### Why the agent never calls a third party directly

If the tool calls Stripe, then auth, rate limits, retries and idempotency live inside the tool — untestable and duplicated per tool. Put your own API in between and all of that becomes ordinary code you own and can test.

Your API layer is also where the tenant boundary is enforced. Never let the model pass a `tenant_id`: take it from the session. A model that can name a tenant can name someone else's.

## The line that decides everything

> **What must always happen is code, not prompt.**

A prompt is guidance the model usually follows. Code is a guarantee.

| Put in the prompt | Put in code |
|---|---|
| Tone, persona, what to prioritise | Permission checks |
| When to ask instead of assume | Tenant isolation |
| Which tool fits which situation | Money, bookings, anything irreversible |
| How to phrase a refusal | Limits, quotas, validation |

If you find yourself writing "never do X" in a prompt, X should be impossible in the tool.

## Non-negotiables

**Idempotency.** The agent will retry, and will call the same tool twice on a bad turn. Every irreversible tool takes a deterministic idempotency key, enforced by a unique index. Same rule as any queue consumer — see `async.md`.

**Max turns.** Every loop needs a ceiling. Without it, a tool that keeps failing becomes an infinite spend.

**State lives outside.** Conversation, partial results and progress go in Postgres or Redis, never in the process. Otherwise you cannot scale the agent horizontally, and a redeploy mid-conversation loses it. Same requirement as any stateless service — see `edge.md`.

**Human in the loop** on anything irreversible or expensive. Confirmation is a design decision, not a fallback.

**Timeouts and a degraded mode.** The model provider will be slow or down. Decide in advance what happens: queue it, fall back to a form, hand off to a person. A circuit breaker with no plan B just converts one error into another.

## Connecting several agents

Reach for these in order. Most systems never need past the first.

| Shape | When | Cost |
|---|---|---|
| **One agent, good tools** | Almost always | Cheapest, easiest to debug |
| **Pipeline** — agent A's output feeds B | Genuinely sequential stages with different jobs | Latency stacks |
| **Supervisor + specialists** | Subtasks needing different tools or permissions | Every hop is a model call and a chance to lose context |
| **Peers negotiating** | Rarely justified | Hard to debug, hard to bound |

> Adding an agent adds a model call, latency, cost and a new failure mode. Adding a tool usually doesn't. **Prefer a tool.**

If you do split, the boundary should follow *permissions or data access*, not "it feels like a different job". A specialist that can only read is worth having. A specialist that just has a different personality is not.

## How you know it works

**Evals or you are guessing.** A set of real cases with expected outcomes, run on every prompt or tool change. A prompt edit is a deploy: it can break things a test would have caught.

**Trace every run** end to end: prompt, each tool call with its arguments and result, tokens, latency. When a user says "it did something weird", the trace is the only way to know what happened.

**Watch the numbers that matter:** tool-call error rate, turns per conversation (rising means it is getting lost), cost per conversation, and how often a human has to step in.

## Failure modes to design against

| Failure | Guard |
|---|---|
| Loops on a failing tool | Max turns, and a typed failure the model can act on |
| Invents arguments | Strict schema, enums over free text, validate before executing |
| Confidently wrong answer | Ground it in tool results, and make "I don't know" an acceptable output |
| Leaks another tenant's data | Tenant from the session, never from the model. Row-level security underneath |
| Prompt injection through user content | Treat retrieved and user content as data, never as instructions. Do not let it choose tools |
| Cost blows up quietly | Budget per conversation, alert on the curve, not on the total |
