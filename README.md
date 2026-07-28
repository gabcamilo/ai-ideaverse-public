# llm-wiki

A local, persistent, **LLM-authored and LLM-maintained knowledge wiki**, operated from Claude Code. It turns curated source material into an interlinked, concept-shaped knowledge base whose primary readers are LLMs — and which compounds in value with every ingest instead of re-deriving understanding on every query.

> RAG is stateless: it reads the same documents and rebuilds the same understanding every time you ask. Human wikis are stateful but die of bookkeeping. This project takes the third path — the LLM does all the bookkeeping, knowledge accumulates as maintained pages, and retrieval stays deterministic until scale proves otherwise.

**Status:** v0.1 — bootstrap. Seeded with a ten-solution research corpus on knowledge management and AI memory systems (Karpathy's LLM Wiki pattern, QMD, GBrain, Graphify, CodeGraph, Hermes Agent, and others).

---

## How it works

```
original source (video / web page / repo / PDF / ...)
        │  solution-sumarizer  (type-dispatched summarization skill)
        ▼
distillate ──► sources/          immutable raw layer
        │  /wiki-ingest
        ▼
wiki pages + _index.yaml         concept-shaped, cross-linked, LLM-maintained
        ▲
        │  /wiki-deepen          escape hatch: back to the original source
        ▼                        when a page needs detail the summary discarded
   /wiki-query                   index-first retrieval, model invoked once
```

Sources enter through the [solution-sumarizer](https://github.com/gabcamilo/solution-sumarizer) skill, which normalizes any input type into a standardized distillate. The wiki's **Ingest** operation then performs a *link inversion*: each source-shaped summary is exploded into concept-shaped pages — one page per solution, technology, concept, pattern, or person — so that cross-cutting knowledge ("which solutions use SQLite FTS5, and why?") lives on pages no single source could contain.

The LLM is the **sole author** of the wiki layer. Humans curate what enters and review what maintenance reports; the machine writes, links, heals, and audits.

## Repository layout

```
WIKI.md                  ← the maintainer's job description: schemas, conventions,
                            operations, whitelists. Read this before touching pages.
_index.yaml              ← canonical index (pages + sources registries).
                            INVARIANT: updated in the same operation as any page write.
sources/                 ← immutable distillates (raw-source layer)
solutions/               ← one page per tool or product
concepts/                ← cross-cutting ideas
technologies/            ← concrete named technologies
patterns/                ← recurring designs
people/                  ← people and organizations
_templates/              ← page templates, extracted from real pages
_reports/                ← lint reports, health.csv, retrieval.csv
scripts/                 ← wikiq.mjs (retrieval scorer), validate-index.mjs,
                            append-health.mjs, hooks installer, cron runner
.claude/commands/        ← the operation slash commands
.claude/agents/          ← wiki-deep-linter subagent
```

## Operations

| Command | What it does |
|---|---|
| `/wiki-ingest <source>` | Integrates a distillate: updates 5–15 pages, performs the link inversion, updates the index, runs micro-lint, commits |
| `/wiki-query <question>` | Index-first retrieval → answer synthesized from wiki pages. Novel syntheses are filed back into the wiki. Gaps are stated explicitly, never papered over |
| `/wiki-lint [--deep]` | Micro: consistency checks on recently touched pages. Deep: whole-wiki pass via subagent — report-first, auto-fixes only whitelisted mechanical categories |
| `/wiki-deepen <page>` | Follows a page's origin URLs back to the original source to recover detail the distillate discarded, or to revalidate a stale page |
| `/wiki-status` | Health at a glance: metrics, pending findings, deepen queue |

## Retrieval

Two paths over the same index, run comparatively (semantic search is deliberately deferred until measured degradation justifies it):

- **Path A** — read `_index.yaml`, open the indicated pages, at most one relationship hop.
- **Path B** — `node scripts/wikiq.mjs "<question>"`: deterministic keyword scoring against the index without opening any file; the model is invoked once, at the end, with evidence assembled.

The routing rule in `CLAUDE.md` makes index-first retrieval the default for every session. Never grep the page directories as a first resort.

## Maintenance

- **Micro-lint** runs inside every ingest, scoped to touched pages.
- **Deep lint** runs weekly via cron (`claude -p`, headless): finds orphans, contradictions, stale pages (volatility-driven revalidation), and promotion candidates. It writes a dated report to `_reports/` and may auto-fix **only**: broken internal links, index drift, missing reciprocal links, and mechanical frontmatter errors. Everything requiring judgment — contradictions, merges, deletions, staleness resolutions — is reported for human review.
- **Audit trail is git.** There is no `log.md`; structured commits (`wiki(ingest): …`, `wiki(lint): …`, `wiki(deepen): …`, `wiki(query): …`) plus the index's sources registry are the record.
- Two guards enforce the index invariant: a Claude Code `PostToolUse` hook (soft, in-session) and a git `pre-commit` hook running the validator (hard gate).

## Page conventions (short version)

Pages are machine-first: dense prose, a fixed heading vocabulary per page type, tight frontmatter (`type`, `aliases`, `volatility`, `revalidate_at`, `sources`), and a typed `## Relationships` edge list (`uses`, `alternative-to`, `implements-pattern`, …) that doubles as a lightweight traversable knowledge graph. Pages are *answer-units* (50–250 lines); a topic earns its own page only under link pressure (3+ inbound references) or weight pressure (a section past ~50 lines) — otherwise it is a section with a stable anchor and an index alias. No stub pages, ever. Full rules live in `WIKI.md`.

## Documentation

| Document | Purpose |
|---|---|
| [`WIKI.md`](WIKI.md) | Operational contract for the LLM maintainer — the highest-leverage file in the repo |
| [`llm-wiki-spec.md`](llm-wiki-spec.md) | Full specification: architecture, schemas, operations, roadmap |
| [`llm-wiki-adr.md`](llm-wiki-adr.md) | Twelve architecture decision records with rationale and rejected alternatives |
| [`llm-wiki-implementation-plan.md`](llm-wiki-implementation-plan.md) | Phase-by-phase build plan with validation gates, executable by an agent |

## Design lineage

The architecture synthesizes a study of ten solutions to the same underlying problem. The load-bearing borrowings: LLM-as-sole-maintainer and the three core operations (Karpathy's LLM Wiki pattern); deterministic index-first retrieval and "make it prove itself" (Second Brain for Claude Code); volatility-driven revalidation and consumer-lens separation (the author's kb plugin); report-first bounded autonomy (Hermes's write-approval, van der Hoeven's sandbox principle); typed-edge relationships at zero infrastructure (Graphify/GBrain); explicit gap visibility in answers (GBrain `think`); and "earn your structure" applied to pages, templates, and schema alike (Nick Milo). The recurring rejected alternative, across nearly every decision: doing more, earlier, on anticipation rather than measurement.

## Roadmap

v0.1 bootstrap → v0.2 retrieval (wikiq + routing) → v0.3 maintenance loop → v0.4 deepen + first revalidation cycle. Backlog: retrieval eval harness and a Path A/B verdict, `wiki_hints` in solution-sumarizer, an optional local semantic-search tier (QMD via MCP) if index retrieval degrades with scale, consumer lens views, and the Obsidian Ideaverse bridge. See `llm-wiki-spec.md` §12.

## Requirements

Claude Code (authenticated), Node.js ≥ 20, git. Local-first: no servers, no databases, no API keys beyond Claude Code itself.

---

*The wiki gets better every time it is used. If it ever doesn't — that's a lint finding.*
