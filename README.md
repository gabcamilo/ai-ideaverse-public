# llm-wiki

A local, persistent, **LLM-authored and LLM-maintained knowledge wiki**, operated from Claude Code. It turns curated source material into an interlinked, concept-shaped knowledge base whose primary readers are LLMs — and which compounds in value with every ingest instead of re-deriving understanding on every query. llm-wiki is a module of the broader **ai-ideaverse** project, which will eventually unite it with the Obsidian Ideaverse PKM vault and full-workspace tooling; this repo stays independently buildable, publishing its state (`dashboard-data.json`, `_index.yaml`) for umbrella-level features to compose.

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

Adoption is enforced by mechanism, not instruction: a gated `UserPromptSubmit` hook scores every prompt against the index and injects the top hits into context when relevant (nothing on irrelevant turns), while telemetry hooks log actual page accesses. Queries run under an escalation budget (top scorer first, one page at a time, soft ceiling) and emit traces from which a **utilization ratio** (pages cited ÷ pages opened) detects context bloat automatically; logged no-answer events are audited by deep lint against the index to detect misses — whose fix is usually index-metadata enrichment, making the index self-tuning. The routing rule in `CLAUDE.md` documents the fallback: index-first, never grep the page directories as a first resort.

## Maintenance

- **Micro-lint** runs inside every ingest, scoped to touched pages.
- **Deep lint** runs weekly via cron (`claude -p`, headless): finds orphans, contradictions, stale pages (volatility-driven revalidation), and promotion candidates. It writes a dated report to `_reports/` and may auto-fix **only**: broken internal links, index drift, missing reciprocal links, and mechanical frontmatter errors. Everything requiring judgment — contradictions, merges, deletions, staleness resolutions — is reported for human review.
- **Audit trail is git.** There is no `log.md`; structured commits (`wiki(ingest): …`, `wiki(lint): …`, `wiki(deepen): …`, `wiki(query): …`) plus the index's sources registry are the record.
- Two guards enforce the index invariant: a Claude Code `PostToolUse` hook (soft, in-session) and a git `pre-commit` hook running the validator (hard gate).
- **Provenance is validated, not assumed.** The full chain — page frontmatter `sources[]` → immutable distillate → `origin_urls` → primary source — is checked by the validator (dangling source refs and registry/distillate URL mismatches fail the commit). Quantitative and adjudicated claims carry inline attribution keys resolving to the page's declared sources, so lint can enumerate every claim a given source touches. Origin liveness (`origin_status`, `last_verified`) is written by a deterministic pre-lint HEAD-check script and by human-triggered Deepen runs — the lint agent itself never touches the network, and unknown liveness renders honestly as `unverified`.

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

The architecture synthesizes a study of ten solutions to the same underlying problem (full citations below). The load-bearing borrowings: LLM-as-sole-maintainer and the three core operations [1]; deterministic index-first retrieval and "make it prove itself" [2]; volatility-driven revalidation and consumer-lens separation (the author's kb plugin, [12]); report-first bounded autonomy [7, 10]; typed-edge relationships at zero infrastructure [4, 6]; explicit gap visibility in answers [4]; and "earn your structure" applied to pages, templates, and schema alike [8, 9]. The recurring rejected alternative, across nearly every decision: doing more, earlier, on anticipation rather than measurement.

## References

1. Andrej Karpathy — *LLM Wiki: A Pattern for Personal Knowledge Bases* (gist) — https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
2. Jay E | RoboNuggets — *Build your Ultimate Second Brain with Claude Fable 5 (before it's too late)* (YouTube, 13:41) — https://www.youtube.com/watch?v=VoKiKvgpk78
3. Tobi Lütke — *qmd* (GitHub) — https://github.com/tobi/qmd
4. Garry Tan — *GBrain* (GitHub, via llms-full.txt) — https://github.com/garrytan/gbrain
5. colbymchenry — *CodeGraph* (GitHub) — https://github.com/colbymchenry/codegraph
6. Safi Shamsi / Graphify Labs — *Graphify* (GitHub) — https://github.com/graphify-labs/graphify
7. Nous Research — *Hermes Agent* (GitHub + docs) — https://github.com/nousresearch/hermes-agent
8. Nick Milo — *Create Your Digital Home: Obsidian Walkthrough* (YouTube) — https://www.youtube.com/watch?v=bVl3IRGOWvk
9. Nick Milo — *This Secret Principle Will Transform Your Notes* (PKM Summit NL 2025, YouTube) — https://www.youtube.com/watch?v=q0pQh69iPWA&list=PLw1ExsV_HfJ6r6I3VF-xeF4PtYiXA-8gF
10. Nicole van der Hoeven — *Do Androids Dream of Second Brains?: Observability and AI for PKM* (PKM Summit Utrecht, YouTube) — https://www.youtube.com/watch?v=BeuaPO0Ezuk
11. Gabriela Camilo — *solution-sumarizer* (GitHub) — https://github.com/gabcamilo/solution-sumarizer
12. Gabriela Camilo — *ai-ideaverse-public* (GitHub) — https://github.com/gabcamilo/ai-ideaverse-public

Note: the `sources/` distillates in this repo are derived summaries of the above; cite the originals, not the distillates.

## Roadmap

v0.1 bootstrap → v0.2 retrieval (wikiq + routing) → v0.3 maintenance loop → v0.4 deepen + first revalidation cycle → v0.5 adoption enforcement & retrieval observability (push-injection, telemetry, query traces, gold question set) → v0.6 governance dashboard (a generated, read-only four-panel projection with a consumption heat overlay — Jay E's layer model, drift-proof by construction). Backlog: harness runner over the gold set and a Path A/B verdict, `wiki_hints` in solution-sumarizer, an optional local semantic-search tier (QMD via MCP) if index retrieval degrades with scale, consumer lens views, and the Obsidian Ideaverse bridge. See `llm-wiki-spec.md` §12.

## Requirements

Claude Code (authenticated), Node.js ≥ 20, git. Local-first: no servers, no databases, no API keys beyond Claude Code itself.

---

*The wiki gets better every time it is used. If it ever doesn't — that's a lint finding.*
