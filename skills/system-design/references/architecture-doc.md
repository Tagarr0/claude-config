# Writing an architecture document

One self-contained HTML file in `docs/arquitectura/`. Template: `../templates/architecture.html`.

Works for both cases:
- **New architecture** — fill it as the decision is made
- **Existing architecture** — read the code and write down what is actually there

## The three rules

**1. Only the tabs this system needs.** Delete the rest, and delete their `<nav>` button too. A tab with placeholder text is worse than no tab.

| Tab | Include when |
|---|---|
| **Mapa** | Almost always. It is the one people open |
| **Flujos** | Something non-obvious happens across pieces |
| **Datos** | There are entities, tenancy or retention worth stating |
| **Contratos** | Someone else has to integrate: endpoints, events, tool schemas |
| **Trade-offs** | A real alternative was rejected |

**2. Never scroll.** `overflow:hidden` is deliberate. If a panel does not fit the viewport, the content is too long — cut it, or split it into two tabs. This is a slide, not a page.

**3. The visual language is fixed, the layout is not.**

Never invent a colour, a shape or an arrow style — those carry meaning and must
read the same in every document. Everything else is yours: add a tab the system
needs, a legend the diagram requires, a component the template did not
anticipate, a second diagram in one tab, a table beside a drawing.

The template is a floor, not a ceiling. If the system genuinely needs something
that is not here, add it — in the same visual language, and say why you added
it.

```
azul   servicio        verde  datos        ámbar  cola / worker
gris   tercero         negro  cliente
──     síncrono        ╌╌     asíncrono
```

Same shape means the same thing in every document. That is the whole point of having a template.

## What does not go in the file

The problem statement, why it was decided, and when to revisit it — say those out loud. They belong in the conversation, not in a slide nobody re-reads.

The file holds what you need **while working**: what the pieces are, how a request travels, what the data looks like, and what you accepted in exchange.

## Drawing well

- Left to right: client → edge → services → data. Third parties on the right
- Every box gets a name **and** a one-line role. A box labelled `Redis` says nothing; `Redis / sesión + rate limit` does
- Label the arrows that are not obvious: `encola`, `throttle`, `lee/escribe`
- Under ten boxes. More than that means the diagram is doing two jobs — split it into two tabs
- `viewBox` fixed, no width or height on the `<svg>`: it scales to whatever screen opens it

## Before you finish

Walk the `SKILL.md` checklist against what you drew. Anything the checklist raises that the diagram does not answer is either a gap in the design or a gap in the drawing. Say which.

Date it in the header. An architecture document with no date is a liability.
