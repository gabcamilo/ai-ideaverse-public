# LLM Wiki — Project Specification

**Status:** Draft v0.1 · 2026-07-28
**Owner:** Gabriela Camilo
**Drafted from:** two-round design interview + analysis of ten reference solutions (LLM Wiki/Karpathy, QMD, GBrain, Graphify, CodeGraph, Hermes Agent, Second Brain for Claude Code, Ideaverse/ACE, Architect & Gardener, PKM Observability & AI Dreaming)

---

## 1. Vision

A local, persistent, LLM-authored and LLM-maintained knowledge wiki, operated from Claude Code, that compounds in value with every ingest. It is the machine-readable knowledge layer of the owner's broader system: a parallel derived layer that sits beside (not inside) the Obsidian Ideaverse vault, optimized for LLM consumption first.

The wiki exists to solve the statelessness problem that all ten reference solutions attack from different angles: RAG re-derives understanding on every query, agents forget between sessions, and human-maintained wikis collapse under bookkeeping burden. Here, the LLM does all bookkeeping (Karpathy's core insight), retrieval is deterministic before it is ever generative (Jay E's core insight), and knowledge is concept-shaped rather than source-shaped.

## 2. Scope

**In scope for v1:** solutions-research knowledge — tools, patterns, architectures, technologies, and the people/orgs behind them, of the kind already produced by the solution-sumarizer pipeline.

**Designed-for-growth:** the schema must be extensible so the wiki can later absorb general-purpose knowledge and grow consumer-specific lenses, without a rewrite. "Starts focused, wants to grow."

**Explicit non-goals for v1:**
- Human-browsing aesthetics (MOC prose, visual polish). Humans can read the wiki, but pages are optimized for machine consumption.
- Semantic/embedding search infrastructure (QMD-style). Deliberately deferred; see §11.
- Consumer lens files (`*-reference.md` views). The only consumer at launch is "Claude answering questions"; the neutral pages are that lens.
- Multi-user access, cloud sync, write concurrency.
- Ideaverse integration. The bridge comes later; the wiki is built standalone first.

## 3. Design principles

1. **LLM as sole author of the wiki layer.** Humans curate what enters; the LLM writes, links, heals, and audits. (Karpathy)
2. **Concept-shaped, not source-shaped.** Ingest's central act is link inversion: exploding source-centric distillates into cross-cutting concept pages. Page linking is the primary carrier of contextual value.
3. **Deterministic before generative.** Retrieval climbs an index-first ladder; the model is invoked once, at the end, with evidence assembled. (Jay E)
4. **Earn your structure.** No page, folder, template, or lens exists before real pressure demands it. (Milo)
5. **Compounding, not accumulating.** Every operation must leave the wiki more complete or more coherent than it found it. Work is never thrown away.
6. **Machine-first page conventions.** Dense prose, predictable stable headings, explicit cross-links, tight frontmatter, no decorative structure.
7. **Local-first.** Everything runs on the owner's machine inside Claude Code. No data egress requirements beyond the LLM calls Claude Code already makes.
8. **Report before repair.** Autonomous maintenance may auto-fix only whitelisted mechanical categories; judgment calls are reported for human review.

## 4. Architecture

Four layers, each with a distinct owner and mutability contract:

| Layer | Contents | Writer | Mutability |
|---|---|---|---|
| Raw sources | solution-sumarizer distillates (+ source URLs to originals) | solution-sumarizer skill | Immutable once ingested |
| Wiki | Markdown pages (Solution, Concept, Technology, Pattern, Person/Org) | LLM only | Continuously maintained |
| Schema | `WIKI.md` job description, `_index.yaml`, minimal templates | Human (with LLM proposals) | Versioned, deliberate changes |
| Retrieval | Path A (index-read) and Path B (deterministic scorer) | Human-authored script + conventions | Stable interface |

### 4.1 Ingestion pipeline (two-stage with escape hatch)

```
original source (video / web page / repo / PDF / ...)
        │  solution-sumarizer (type-dispatch adapters, e.g. claude-video watch)
        ▼
distillate  ──►  raw sources layer (immutable)
        │  Ingest operation
        ▼
wiki pages updated / created  +  _index.yaml updated  +  micro-lint
        ▲
        │  Deepen operation (on demand, when the distillate is insufficient:
        │  follow frontmatter source URLs back through the same adapters)
original source
```

The summarizer is the front door and remains a separate, reusable skill. The wiki never loses access to detail the distillate discarded, because Deepen can always return to the original.

**Future enhancement (backlog):** extend solution-sumarizer to emit a `wiki_hints` frontmatter block — candidate entities and relations noticed during summarization — so Ingest starts from a link worksheet.

### 4.2 Repository layout

```
llm-wiki/                        ← its own git repository
├── WIKI.md                      ← the schema document: LLM job description,
│                                   conventions, operation workflows, whitelists
├── _index.yaml                  ← canonical index: pages registry + sources registry
├── _templates/                  ← only templates with ≥3 real instances
├── _reports/                    ← lint reports, retrieval benchmarks, health metrics
├── sources/                     ← immutable distillates (raw-source layer)
├── solutions/                   ← one page per tool/product (qmd.md, gbrain.md, ...)
├── concepts/                    ← cross-cutting ideas (hybrid-search.md, ...)
├── technologies/                ← concrete tech (tree-sitter.md, sqlite-fts5.md, ...)
├── patterns/                    ← recurring designs (index-first-retrieval.md, ...)
├── people/                      ← people and orgs (karpathy.md, nous-research.md, ...)
├── gold/                        ← questions.yaml: question → expected pages (v0.5)
└── scripts/
    ├── wikiq.mjs                ← Path B deterministic scorer (also imported by push-injection)
    ├── validate-index.mjs       ← V1–V8 invariant checks (pre-commit + micro-lint)
    ├── inject-context.mjs       ← gated UserPromptSubmit push-injection (v0.5)
    ├── log-access.mjs           ← telemetry hook logger (v0.5)
    ├── append-health.mjs        ← health.csv appender
    ├── check-origins.mjs        ← origin liveness HEAD checks (cron wrapper, never the lint agent)
    ├── build-dashboard.mjs      ← governance projection generator (v0.6)
    └── install-hooks.sh / cron-deep-lint.sh
```

No `log.md`. Git history is the audit log: every Ingest, Lint, and Deepen run ends in a structured commit (see §8.5). The `sources:` section of `_index.yaml` provides the cheap "what has been ingested" lookup that git history alone would make expensive.

## 5. Page taxonomy

Five types at launch, iterated as need arises:

| Type | One page per | Examples from current corpus |
|---|---|---|
| Solution | tool / product / framework | QMD, GBrain, Graphify, CodeGraph, Hermes |
| Concept | cross-cutting idea | hybrid search, compounding memory, gap analysis, knowledge graph |
| Technology | concrete named tech | tree-sitter, SQLite FTS5, sqlite-vec, MCP, GGUF models |
| Pattern | recurring design | index-first retrieval, background consolidation, sandbox-and-merge, type-dispatch ingestion |
| Person/Org | notable author / org | Karpathy, Tobi Lütke, Nick Milo, Nous Research, Grafana Labs |

Candidate future types (add only when three real instances exist): Comparison, Decision (records of the owner's own architectural choices).

### 5.1 Atomicity rules

The unit of design is the **answer-unit**: a page should fully answer a class of questions without forcing extra hops, since every hop is a file read costing tokens and latency for the LLM reader.

- Target size 50–250 lines.
- A topic starts as a **section with a stable heading** inside its most natural parent page. The index may address it directly as `page.md#section`.
- A section is **promoted to its own page** only under pressure: (a) *link pressure* — referenced from 3+ pages, or (b) *weight pressure* — the section exceeds ~50 lines.
- **Never create stub pages.** A name that deserves findability but not a page becomes an alias in `_index.yaml` pointing at the page/anchor that covers it.
- Concretely: `hybrid-search.md` exists from day one (already cross-referenced by four solutions); BM25 lives as a section inside it until it earns promotion.

### 5.2 Page frontmatter schema

```yaml
---
type: solution | concept | technology | pattern | person
title: "SQLite FTS5"
aliases: ["FTS5", "SQLite full-text search"]
volatility: high | medium | low | static
revalidate_at: 2026-10-28        # computed from volatility at write time
revalidate: false                # manual flag; true forces revalidation
sources: ["sources/qmd.md", "sources/codegraph.md"]   # provenance
created: 2026-07-28
updated: 2026-07-28
---
```

Revalidation semantics are adopted from the owner's kb plugin: a page is **stale** when `revalidate: true` or `revalidate_at` is in the past. Volatility defaults by type — Solution: high, Technology: medium, Pattern/Concept: low, Person/Org: low. Stale pages form Deep Lint's prioritized work queue. (The two projects remain independent; the wiki reuses ideas and may diverge freely.)

### 5.3 Page body conventions (machine-first)

- Fixed heading vocabulary per page type, defined in `WIKI.md` (e.g., Solution pages: `## What it is`, `## Problem it solves`, `## How it works`, `## Relationships`, `## Assessment`). Stable headings make anchors durable and grep predictable.
- Every entity mention that has a wiki page or index alias is a markdown link on first mention per section.
- Each page ends with a `## Relationships` section: typed outbound links in the form `- uses → [[technologies/sqlite-fts5]]`, `- alternative-to → [[solutions/gbrain]]`. This is the traversable edge list — the wiki's lightweight knowledge graph, in the Graphify/GBrain spirit but at zero extra infrastructure.
- **Tiered attribution.** Ordinary synthesis inherits the page's `sources` frontmatter silently. Quantitative claims, benchmark figures, and any claim that survived a contradiction adjudication carry an inline footnote-style key (`[^source-id]`) resolving to the page's `sources[]` list — machine-parseable, validator-checked, and queryable by lint ("all claims from source X"). Provenance precision only where numbers or disagreement make it load-bearing.
- No decorative bullets, no images, no mermaid in wiki pages (those belong to human-facing artifacts; distillates in `sources/` keep theirs).

## 6. The index: `_index.yaml`

The single canonical index, replacing Karpathy's `index.md`, serving both retrieval paths and the audit lookup:

```yaml
pages:
  - id: sqlite-fts5
    path: technologies/sqlite-fts5.md
    type: technology
    title: "SQLite FTS5"
    aliases: ["FTS5", "SQLite full-text search"]
    summary: "SQLite's built-in BM25 full-text engine; retrieval backbone of QMD, CodeGraph, Hermes."
    keywords: [sqlite, bm25, full-text, search]
    inbound: 4            # maintained by lint; scoring signal + promotion detector
    volatility: medium
    updated: 2026-07-28

sources:
  - id: qmd
    path: sources/qmd.md
    ingested: 2026-07-28
    origin_urls: ["https://github.com/tobi/qmd"]   # canonical copy lives in the distillate's frontmatter; validator keeps these equal
    origin_status: alive          # alive | dead | moved | unverified — written by check-origins + Deepen, never by lint
    last_verified: 2026-07-28
    pages_touched: [qmd, sqlite-fts5, hybrid-search, mcp, ...]   # historical ingest snapshot
    derived_pages: [qmd, sqlite-fts5, hybrid-search, mcp, ...]   # computed: pages whose frontmatter lists this source
```

**Critical invariant (the load-bearing rule from the entire corpus):** the index is updated in the same operation as any page write. An index that drifts from reality silently destroys the retrieval layer's advantage. Micro-lint verifies index/filesystem agreement on every ingest.

## 7. Retrieval

Two parallel paths over the same index, run comparatively until data picks a winner (see §11 for the deferred formal harness):

**Path A — index-read.** Claude reads `_index.yaml` (or the relevant slice), chooses pages, opens them, follows at most one `Relationships` hop, answers. Zero infrastructure; the Karpathy baseline.

**Path B — deterministic scorer (`scripts/wikiq`).** A script in the brain.js spirit: strips the question to keywords → scores every index entry against `title + aliases + summary + keywords` without opening any file (inbound count as a boost factor) → returns the top-k ranked entries with paths and anchors. Claude then opens only the top scorer(s), reads the relevant section, follows at most one pointer, and answers. No model call occurs before the final answer step.

**Adoption is enforced by mechanism, not instruction (ADR-013).** A `UserPromptSubmit` hook runs wikiq against every prompt and injects the top-k index hits (id, path, one-line summary — index entries only, no pages opened) into context when the top score clears a relevance threshold; below the threshold, nothing is injected and the turn pays no token tax. Access telemetry hooks (`PreToolUse`/`PostToolUse` on Read/Grep/Glob over page directories) log actual retrieval behavior to `_reports/access-trace.jsonl` for the §10 metrics and lint anti-pattern detection. Consumer subagent definitions must carry an explicit wiki-consultation clause. A routing note in `CLAUDE.md` documents the mechanism and states the fallback rule: *check `_index.yaml` (via wikiq when available) before any grep/glob over the wiki.*

**Expected dynamics, stated up front to keep the comparison honest:** while the wiki is small, Path A wins or ties (the whole index fits trivially in context — CodeGraph's floor effect). The decision signal is the trend as the wiki grows, not the day-one result.

## 8. Operations

Four operations. Each has a trigger, a bounded scope, a defined output, and a structured commit.

### 8.1 Ingest
- **Trigger:** human provides a new distillate (or asks for source → summarizer → ingest end-to-end).
- **Steps:** read distillate → identify affected pages (typically 5–15) → update/create pages, performing the source→concept link inversion → update `_index.yaml` (pages + sources registries) → **link audit**: for every entity the distillate mentions, verify the corresponding wiki page now links back to the new solution, and vice versa → **micro-lint** (see 8.3) on touched pages → structured commit.

### 8.2 Query
- **Trigger:** human asks a question in Claude Code.
- **Steps:** Path A or B retrieval under the **escalation budget** (ADR-014): open the top-scoring page first; each additional page may be opened only if the previous one failed to answer; soft ceiling of 5 pages per query, beyond which the justification must be recorded in the trace → synthesize answer from wiki pages (not raw sources) → if the answer is a *novel synthesis* not present on any page, file it back into the appropriate page(s) and commit (Karpathy's compounding rule). If the wiki cannot answer, say so explicitly — gap visibility over confident omission (GBrain's `think` principle) — log the no-answer event, and propose an ingest or deepen.
- **Trace:** every query appends a record to `_reports/queries.jsonl`: question, ranked candidates, pages opened, pages cited in the answer, token cost. Cited ÷ opened is the per-query **utilization ratio** — the mechanical bloat detector.

### 8.3 Lint
Two tiers:
- **Micro-lint (every ingest, scoped to touched pages):** internal links resolve; index entries match files; frontmatter valid; `Relationships` sections bidirectional where required; heading vocabulary respected.
- **Deep lint (scheduled):** whole-wiki pass — orphan pages (no inbound links), contradictions between pages, stale pages (revalidation queue, priority-ordered), promotion candidates (sections under link/weight pressure), index drift, alias collisions. It also audits retrieval behavior from the §10 traces (ADR-014): *missed-retrieval* (a logged no-answer where an existing page plainly covers the question — corrective action targets index metadata: aliases, keywords, summary), *low-utilization* (aggregate cited÷opened ratio declining), *grep-first violations* and *ceiling-exceeded* queries (from the access trace). Output is a dated report in `_reports/`.

**Auto-fix whitelist (deep lint may repair without asking):** broken internal links, index drift, missing reciprocal links, frontmatter mechanical errors.
**Report-only (human decides):** contradictions, staleness resolutions (which claim wins), page merges/splits/promotions, deletions.

### 8.4 Deepen
- **Trigger:** a query or lint finding needs detail the distillate discarded, or a stale page needs revalidation against its origin.
- **Steps:** resolve the page's `sources` → follow `origin_urls` through the appropriate type adapter → extract the missing detail → update the page (and only pages justified by the new material) → record `origin_status` + `last_verified` on the touched sources-registry entries (Deepen runs are the human-triggered network context; liveness data accrues opportunistically) → commit. Deepen is also the mechanism Deep Lint uses to revalidate stale pages — via queued tasks, never autonomously (§14.3).

### 8.5 Commit convention

```
wiki(ingest): qmd — 7 pages touched, 2 created
wiki(lint): deep pass 2026-08-04 — 3 auto-fixes, 2 findings reported
wiki(deepen): sqlite-fts5 — revalidated against origin, volatility→low
wiki(query): filed back synthesis into concepts/hybrid-search.md
```

Git history + `_index.yaml`'s sources registry fully replace `log.md`.

## 9. Maintenance cadence

- **Micro-lint:** coupled to every ingest. Always on.
- **Deep lint:** scheduled weekly via cron running Claude Code headless (`claude -p "/wiki:lint --deep"`), report-first with the §8.3 whitelist. Cadence and autonomy widen only after the report history shows the auto-fixes are trustworthy.
- **Slash commands** (Claude Code custom commands): `/wiki:ingest`, `/wiki:query`, `/wiki:lint [--deep]`, `/wiki:deepen <page>`, `/wiki:status`.

## 10. Observability

Two planes, one report directory (ADR-013, ADR-014):

**Wiki health (structure).** Deep lint appends one row per run to `_reports/health.csv`: date, page count by type, total links, orphan count, stale count, average inbound per page, index size — plus aggregate utilization ratio and miss-finding count.

**Retrieval behavior (consumption).** `_reports/queries.jsonl` is the canonical per-query trace (question, candidates, opened, cited, tokens); `_reports/access-trace.jsonl` records every page-directory access from the telemetry hooks; `_reports/retrieval.csv` is retained only for milestone harness comparisons (§11). Together these answer the two consumption questions no health metric can: *is the wiki actually being used*, and *is each query reading just enough* — bloat detected via the utilization ratio without any ground truth, misses detected via the no-answer audit and, from v0.5, the gold question set.

This is the van der Hoeven-style observability layer, arrived at incrementally; the promotion detector (`inbound` counts) and the self-tuning index loop (miss finding → metadata enrichment) both feed off the same data.

## 11. Retrieval evaluation harness *(tooling deferred; gold set scheduled — ADR-011 as amended by ADR-014)*

The **gold question set** is authored by the owner at v0.5 in the upgraded format *question → expected pages* (10–15 real questions, each listing the page ids a correct retrieval should surface), making it a direct recall instrument rather than only an answer-quality check. Harness runner tooling remains deferred: when activated, each question is answered via Path A and Path B, comparing token cost, wall time, answer correctness, and retrieval recall against the expected pages; re-run at milestones (every ~25 pages) and logged to `_reports/retrieval.csv`. The question set doubles as a schema stress test: any question unanswerable by traversing the taxonomy indicates a taxonomy defect. Until the harness runs, the §10 traces (utilization ratio, miss audit) provide continuous proxy measurement.

## 12. Roadmap

**v0.1 — Bootstrap.** Write `WIKI.md` (the highest-leverage artifact in the whole system). Create repo layout, `_index.yaml`, Solution + Concept templates. Ingest the ten existing distillates. Expect ~30–50 pages and a dense first link graph.

**v0.2 — Retrieval.** Implement `scripts/wikiq` (Path B). Add the `CLAUDE.md` routing note. Begin informal A/B usage.

**v0.3 — Maintenance loop.** Implement micro-lint checks, deep lint with report + whitelist, health.csv, weekly headless cron.

**v0.4 — Deepen.** Wire type adapters for the deepen path; run first revalidation cycle on high-volatility Solution pages.

**v0.5 — Adoption & retrieval observability (ADR-013, ADR-014).** Gated push-injection hook; access telemetry hooks; query traces with utilization ratio and escalation budget; deep lint retrieval-behavior audits; owner authors the gold question set (question → expected pages).

**v0.6 — Governance dashboard (ADR-015).** `build-dashboard.mjs` emitting a self-contained `dashboard.html` + `dashboard-data.json`: four panels (Pages, Sources, Operations, Automations) mapped from Jay E's layer model, with the consumption heat overlay from the v0.5 traces. Regenerated by every deep lint; `/wiki-status --visual`.

**Future iterations (unordered backlog):**
- Harness runner tooling over the v0.5 gold set (§11) and a Path A/B decision.
- `wiki_hints` emission in solution-sumarizer.
- Semantic search tier: QMD-style local hybrid search over the wiki, exposed via MCP — added only if/when index+scorer retrieval degrades with scale.
- Consumer lenses (`*-reference.md` views) as real consumers appear. When a human-facing lens materializes, diagrams are **generated projections, never stored content**: rendered on demand from each page's `## Relationships` edge lists via the mermaid-diagram skill (see References, item 14), shown, then discarded — the ADR-015 read-only-projection philosophy applied to diagrams, drift-proof because nothing persistent exists to drift. Mermaid remains banned from wiki pages (§5.3); distillate-side diagram conventions are a solution-sumarizer concern, outside this module's boundary.
- **ai-ideaverse umbrella features** (sibling modules, not wiki features): llm-wiki is one module of the owner's broader **ai-ideaverse** project, alongside the Obsidian Ideaverse PKM vault and future full-workspace tooling. The workspace-level governance surface (Jay E's full audit: all MCP connectors, routines, skills across the whole Claude Code setup) and the wiki↔vault bridge live at umbrella level, composing data each module publishes (the wiki's contribution: `dashboard-data.json` and the index). Modules keep their truth boundaries; the umbrella aggregates. Each gets its own ADR when designed.
- General-purpose knowledge domains beyond solutions research.

## 13. Decision log (from the design interview)

| # | Decision | Choice | Rejected alternatives |
|---|---|---|---|
| 1 | Topology | Parallel derived layer beside the vault | Inside the vault; index-only over the vault |
| 2 | Primary reader | LLMs | Human-first, mixed-first |
| 3 | Ingestion | Two-stage (summarizer → distillate → ingest) + Deepen escape hatch | Direct raw-source ingest |
| 4 | Write authority | LLM sole author of wiki layer | Sandbox-and-merge staging |
| 5 | Infrastructure | Local, Claude Code; cost-tolerant during development | Cloud services |
| 6 | Index format | `_index.yaml` (structured, dual-consumer) | `index.md` prose catalog |
| 7 | Audit trail | Git history + sources registry | `log.md` |
| 8 | Maintenance | Micro-lint per ingest + weekly deep lint, report-first, whitelisted auto-fix | On-demand only; full autonomy |
| 9 | Retrieval v1 | Paths A and B in parallel over one index | Immediate semantic search |
| 10 | kb plugin relationship | Independent project; reuses ideas (revalidation frontmatter, lens concept), free to diverge | Merge into kb; enforced shared conventions |
| 11 | Eval harness | Deferred to future iteration | Build with v0.1 |
| 12 | Scope | Solutions research now, extensible schema for growth | General-purpose from day one |
| 13 | Wiki adoption | Gated push-injection (threshold-filtered wikiq on every prompt) + access telemetry + subagent clauses | Advisory instruction only; always-on injection; MCP-gated access |
| 14 | Retrieval efficiency | Query traces, utilization ratio, escalation budget (soft ceiling 5), miss audit feeding index enrichment; gold set (question→expected-pages) authored at v0.5 | No measurement; full harness now; treating misses as scorer bugs first |
| 15 | Governance dashboard | Generated read-only projection (`dashboard.html` + `dashboard-data.json`), wiki-scoped, four Jay E-mapped panels + consumption heat overlay, rebuilt by deep lint | Hand-maintained live dashboard; no visual layer; full-workspace scope inside this module (deferred to the ai-ideaverse umbrella) |
| 16 | Provenance enforcement | Validator-checked chain (page→distillate→origin, V7) with computed `derived_pages`; tiered inline attribution keys for quantitative/adjudicated claims (V8); origin liveness via deterministic check-origins in the cron wrapper + opportunistic Deepen writes — lint agent stays networkless | Sentence-level citation everywhere; declared-but-unvalidated provenance; networked lint agent; liveness flags with no owner |

## 14. Open questions

1. The exact heading vocabulary per page type — to be settled while writing `WIKI.md`, ideally by drafting two real pages first and extracting the template from them (earn the structure, even for templates).
2. The typed-relationship vocabulary for `## Relationships` sections (`uses`, `alternative-to`, `built-by`, `implements-pattern`, ...) — start minimal, let lint report unknown types.
3. Whether Deep Lint's stale-page revalidation should be allowed to call Deepen autonomously (network access to origins) or only queue deepen tasks for human-triggered runs.
4. wikiq implementation language (JS for zero-setup in Claude Code vs. TS) and its exact scoring function — decided at v0.2.

---

## 15. References

Short names used throughout this specification (Karpathy, Jay E, QMD, GBrain, CodeGraph, Graphify, Hermes, Milo, van der Hoeven) resolve to the primary sources below. The project's `sources/` distillates are derived summaries and are not the citable sources.

1. Andrej Karpathy — *LLM Wiki: A Pattern for Personal Knowledge Bases* (GitHub gist) — https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
2. Jay E | RoboNuggets — *Build your Ultimate Second Brain with Claude Fable 5 (before it's too late)* (YouTube, 13:41) — https://www.youtube.com/watch?v=VoKiKvgpk78
3. Tobi Lütke — *qmd (Query Markup Documents)* (GitHub) — https://github.com/tobi/qmd
4. Garry Tan — *GBrain* (GitHub; analyzed via llms-full.txt) — https://github.com/garrytan/gbrain · https://raw.githubusercontent.com/garrytan/gbrain/master/llms-full.txt
5. colbymchenry — *CodeGraph* (GitHub) — https://github.com/colbymchenry/codegraph
6. Safi Shamsi / Graphify Labs — *Graphify* (GitHub) — https://github.com/graphify-labs/graphify
7. Nous Research — *Hermes Agent* (GitHub + documentation) — https://github.com/nousresearch/hermes-agent · https://hermes-agent.nousresearch.com/docs/developer-guide/architecture
8. Nick Milo (Linking Your Thinking) — *Create Your Digital Home: Obsidian Walkthrough* (Ideaverse for Obsidian; YouTube) — https://www.youtube.com/watch?v=bVl3IRGOWvk
9. Nick Milo (Linking Your Thinking) — *This Secret Principle Will Transform Your Notes* (Architect & Gardener; PKM Summit NL 2025; YouTube) — https://www.youtube.com/watch?v=q0pQh69iPWA&list=PLw1ExsV_HfJ6r6I3VF-xeF4PtYiXA-8gF
10. Nicole van der Hoeven — *Do Androids Dream of Second Brains?: Observability and AI for PKM* (PKM Summit Utrecht; YouTube, 43 min) — https://www.youtube.com/watch?v=BeuaPO0Ezuk
11. Gabriela Camilo — *solution-sumarizer* (GitHub) — https://github.com/gabcamilo/solution-sumarizer
12. Gabriela Camilo — *ai-ideaverse-public* (GitHub, public working-repo copy) — https://github.com/gabcamilo/ai-ideaverse-public
13. Project owner — *AI Knowledge & Context Management: Six Concepts Compared* (internal research doc, 2026-07-22; adversarial ingest fixture C26) — its references resolve to items 1, 3–7 above.
14. Gabriela Camilo — *mermaid-diagram* (GitHub; designated renderer for future human-lens diagram projections, §12) — https://github.com/gabcamilo/mermaid-diagram
