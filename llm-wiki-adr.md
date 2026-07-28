# LLM Wiki — Architecture Decision Records

**Format:** consolidated ADR log (Nygard style: Context → Decision → Rationale → Consequences).
**Scope:** decisions made during the design interview of 2026-07-28, cross-referenced with the ten analyzed reference solutions.
**Companion document:** `llm-wiki-spec.md` (the specification these decisions produced).

All records are **Accepted** unless marked otherwise. Reference solutions are cited by name: Karpathy's LLM Wiki pattern, QMD, GBrain, Graphify, CodeGraph, Hermes Agent, Second Brain for Claude Code (Jay E), Ideaverse/ACE and Architect & Gardener (Milo), PKM Observability & AI Dreaming (van der Hoeven).

---

## ADR-001 — The wiki is a parallel derived layer, not part of the Ideaverse vault

**Context.** Three topologies were possible: the wiki as a folder inside the Obsidian vault sharing its link graph; a separate derived layer maintained by the LLM; or no synthesized layer at all, only retrieval infrastructure over the vault (the QMD model).

**Decision.** The wiki is a standalone repository beside the vault. It reads from curated sources; the vault remains an exclusively human space.

**Rationale.** The two spaces have incompatible authorship and audience contracts. The Ideaverse is human-authored and optimized for human sense-making (Milo's frameworks depend on the human doing the linking and clustering — that friction *is* the value). The wiki is LLM-authored and machine-read; mixing the two would either pollute the human space with machine-generated pages or constrain the LLM's conventions to human aesthetics. Karpathy's three-layer model makes the same separation for the same reason: each layer needs a distinct owner and mutability contract. The pure-index alternative (QMD-style) was rejected because it forfeits the central prize — compounding synthesized knowledge. An index makes retrieval cheaper; it never makes the knowledge itself better.

**Consequences.** Clean mutability contracts and no risk to the vault. The cost is a deferred integration problem: the Ideaverse bridge becomes a future project (roadmap backlog) rather than a built-in property. Canonicality between wiki and vault will need definition when the bridge is designed.

---

## ADR-002 — LLMs are the primary readers

**Context.** A wiki optimized for human browsing wants MOC-style prose, visual hierarchy, and navigational comfort. One optimized for machine consumption wants density, stable headings, predictable conventions, and minimal hop counts. Serving both first-class doubles the design constraints.

**Decision.** Pages are optimized for LLM consumption. Humans may read them but are not the design target.

**Rationale.** The wiki's job is to make Claude Code sessions smarter and cheaper. Every human-facing nicety (decorative structure, narrative transitions, visual elements) is token overhead for the machine reader; every machine-facing convention (fixed heading vocabulary, dense frontmatter) is mildly hostile to casual human reading. Choosing one audience resolves every downstream formatting question mechanically. The human-facing view is not lost — it is deferred to a future consumer lens (see ADR-010), which is the correct place for it: a projection of neutral knowledge, not a constraint on it.

**Consequences.** Page conventions in the spec (§5.3) are unapologetically machine-first. A human-oriented lens becomes the natural shape of the future Ideaverse bridge.

---

## ADR-003 — Two-stage ingestion through solution-sumarizer, with a Deepen escape hatch

**Context.** The owner already maintains solution-sumarizer, a skill that dispatches by input type (video, web page, repo, PDF) and emits standardized distillate documents. The wiki could ingest raw sources directly through similar adapters (one-stage), or treat the summarizer's output as its raw-source layer (two-stage). The known risk of two-stage is double distillation: the summarizer discards detail a wiki page might later need.

**Decision.** Two-stage: original source → solution-sumarizer → immutable distillate → wiki ingest. A fourth wiki operation, **Deepen**, follows the distillate's preserved origin URLs back through the type adapters whenever a page needs detail the summary discarded.

**Rationale.** Two-stage reuses a proven asset instead of duplicating its dispatch logic, produces a durable per-source artifact independent of the wiki, and makes ingest cheaper by working from pre-structured, already-dense text. The information-loss objection — the only serious argument for one-stage — is neutralized rather than accepted: because every distillate carries its origin URLs in frontmatter, loss is recoverable on demand instead of permanent. Deepen converts the weakness of the chosen option into a bounded, explicit operation, which is strictly better than paying full-extraction cost on every ingest to insure against detail that most pages will never need.

**Consequences.** solution-sumarizer becomes the wiki's front door and a hard dependency of the ingestion path. Its output contract must be treated as an interface (the SKILL.md must be shared at build time). Deepen adds a fourth operation to Karpathy's three, with its own trigger, scope, and commit convention. A `wiki_hints` frontmatter enhancement to the summarizer is banked as future work.

---

## ADR-004 — The LLM is the sole author of the wiki layer (Karpathy model)

**Context.** The corpus offers three trust postures toward machine-written knowledge: full authorship (Karpathy — the LLM writes and heals the wiki directly), sandbox-and-merge (van der Hoeven — the agent writes to a staging folder, the human reviews and merges), and gated writes (Hermes — write-approval on the agent's self-authored skills).

**Decision.** Full authorship: the LLM writes directly to the wiki layer. Trust is bounded not at the write path but at the *maintenance autonomy* level (see ADR-008).

**Rationale.** The sandbox model exists to protect a canonical human space from an agent — van der Hoeven sandboxes Iris because the vault is her primary, human-authored asset. Here that concern dissolves by construction: ADR-001 already separated the wiki from the human space, and ADR-002 made the LLM its primary reader. A human review gate on every ingest would reintroduce exactly the bookkeeping burden the pattern exists to eliminate — Karpathy's diagnosis is that knowledge bases die of administrative overhead, and a merge queue is administrative overhead. Risk is instead managed where errors are actually dangerous: autonomous background modification, which ADR-008 constrains to a whitelist.

**Consequences.** Ingest and query file-back are frictionless. The quality of `WIKI.md` (the LLM's job description) becomes the single most important artifact in the system — with a sole machine author, the schema document is the only thing standing between coherence and drift. Git history provides full reviewability after the fact without gating anything before it.

---

## ADR-005 — Local-first, operated from Claude Code

**Context.** The reference solutions span fully offline stacks (QMD's GGUF models, CodeGraph's local SQLite) to cloud-backed infrastructures (GBrain's provider matrix, with a documented 25× cost spread across modes).

**Decision.** The wiki lives on the owner's machine as a git repository, operated entirely through Claude Code. No additional cloud services. Cost efficiency is a goal, but extra token spend is acceptable during early development.

**Rationale.** The owner lives in Claude Code; the wiki should meet its operator where the work already happens, with zero new infrastructure to stand up or maintain. Locality also keeps the privacy posture simple (nothing leaves the machine beyond the LLM calls Claude Code already makes) and keeps every component — pages, index, scripts, reports — inspectable as plain files. GBrain's cost lesson is absorbed as a sequencing principle rather than an architecture: start with the zero-infrastructure retrieval tier and let measured degradation, not anticipation, justify heavier machinery (ADR-009, ADR-012).

**Consequences.** No server processes, no databases, no API keys beyond Claude Code itself. Scheduled maintenance uses Claude Code headless mode via cron. The semantic-search tier, if ever needed, must also satisfy the local constraint (QMD is the pre-identified candidate precisely because it is fully offline).

---

## ADR-006 — `_index.yaml` replaces Karpathy's `index.md` as the canonical index

**Context.** Karpathy specifies a prose catalog (`index.md`) as the wiki's entry point. Jay E's Second Brain demonstrates that a small structured index is the load-bearing component of deterministic retrieval — scoring happens against the index alone, without opening files. The owner's kb plugin already uses a structured `_index.yaml` registry successfully.

**Decision.** A single structured YAML index containing a pages registry (id, path, type, title, aliases, summary, keywords, inbound count, volatility) and a sources registry (what has been ingested, when, from where, touching which pages).

**Rationale.** One artifact serves every consumer. Path A (Claude reading the index for navigation) loses nothing — LLMs read YAML as fluently as prose. Path B (the deterministic scorer) gains everything — scoring requires structured fields, and a prose catalog would need parsing heuristics that defeat the determinism. The sources registry additionally absorbs the audit-lookup role vacated by `log.md` (ADR-007). A prose index would have required either maintaining two indexes in sync (a drift surface) or crippling Path B.

**Consequences.** The index-update invariant becomes the system's critical maintenance rule: the index is written in the same operation as any page write, and micro-lint verifies index/filesystem agreement on every ingest. This is a deliberate import of Jay E's hardest-won lesson — a drifting catalog silently degrades the entire retrieval advantage. The `inbound` field doubles as the promotion detector for atomicity rules.

---

## ADR-007 — Git history replaces `log.md`

**Context.** Karpathy's pattern includes `log.md`, an append-only chronological record of every operation, maintained by the LLM. The wiki lives in a git repository.

**Decision.** No `log.md`. Structured commit messages (`wiki(ingest): …`, `wiki(lint): …`, `wiki(deepen): …`, `wiki(query): …`) are the audit trail. The `sources:` registry in `_index.yaml` provides the cheap "what has been ingested" lookup.

**Rationale.** `log.md` predates the assumption of version control; under git it is a redundant, hand-maintained shadow of information the VCS records automatically, with better tooling (diff, blame, bisect) and zero drift risk. Every LLM-maintained file is a surface the LLM can corrupt and lint must audit — eliminating one is a direct reliability gain. The single capability git lacks (cheap ingestion lookup without walking history) is covered by the sources registry, which the index needs anyway for provenance.

**Consequences.** Commit message structure becomes part of the schema contract in `WIKI.md` — commits are load-bearing, not cosmetic. Audit quality now depends on commit discipline, which lint conventions must enforce.

---

## ADR-008 — Maintenance: ingest-coupled micro-lint plus scheduled report-first deep lint with an auto-fix whitelist

**Context.** The corpus is unanimous that periodic consolidation is what separates compounding knowledge from compounding errors (Karpathy's Lint, GBrain's Dream Cycle, Open Claw's dreaming pipeline, Milo's Garden Master — the same mechanism in four costumes). It disagrees on autonomy: from human habit to fully autonomous nightly cron. Options considered: on-demand only; micro-lint coupled to ingest; scheduled deep lint; and combinations.

**Decision.** Both tiers, with asymmetric trust. Micro-lint runs on every ingest, scoped to touched pages. Deep lint runs weekly via headless cron, produces a report first, and may auto-fix only whitelisted mechanical categories (broken internal links, index drift, missing reciprocal links, frontmatter errors). Judgment calls — contradictions, staleness resolutions, merges/splits, deletions — are report-only.

**Rationale.** On-demand-only was rejected on Karpathy's own diagnosis: "when I feel like it" is precisely the human bookkeeping failure the pattern exists to eliminate. Micro-lint alone was rejected because it is structurally blind to global defects — orphans, cross-page contradictions, staleness — that only a whole-wiki pass can see. Full autonomy was rejected because ADR-004 made the LLM the sole author: a defective unsupervised lint pass could damage pages with nobody watching, and unlike ingest errors (bounded to one source's blast radius), lint errors can touch anything. The report-first whitelist follows Hermes's write-approval insight — gate the machine's self-modification where it is riskiest — while keeping mechanical healing frictionless. The split between mechanical and judgment categories is the operational definition of that boundary.

**Consequences.** Deep lint reports accumulate in `_reports/`, creating both a review queue and — deliberately — the evidence base for widening the whitelist later. Autonomy is designed to be earned from the report history, not granted up front.

---

## ADR-009 — Retrieval v1: Paths A and B in parallel over one index; semantic search deferred

**Context.** Retrieval options ranked by infrastructure weight: (a) index-read — Claude reads `_index.yaml` and opens pages; (b) deterministic scorer — a script ranks index entries without opening files (Jay E's brain.js pattern); (c) local hybrid semantic search (QMD: BM25 + vectors + reranking, ~2 GB of models, MCP server).

**Decision.** Build (a) and (b) together over the same index and run them comparatively. Defer (c) until measured degradation justifies it. Design nothing that would block (c) from slotting in later.

**Rationale.** (a) and (b) are not rival systems — (b) is a thin script over the exact same artifact (a) reads, so running both costs almost nothing and converts an architectural guess into an empirical question. Immediate semantic search was rejected on three grounds. First, the corpus's own evidence: embedding search earns its cost on messy, heterogeneous human text, but ADR-002/ADR-004 guarantee this wiki's pages are born well-structured, consistently formatted, and densely lined — the conditions under which deterministic index scoring performs best (Jay E's measured 40% token reduction came from exactly this setup). Second, CodeGraph's floor effect: at small corpus size, heavier retrieval machinery adds round-trip overhead without benefit. Third, ADR-005's infrastructure minimalism. The honest expectation is recorded in the spec: Path A wins early; the decision signal is the trend as the wiki grows.

**Consequences.** `scripts/wikiq` is a v0.2 deliverable. A formal eval harness is deferred (ADR-011), so early comparison is informal. QMD is pre-identified as the (c) candidate because it satisfies the local constraint and speaks MCP.

---

## ADR-010 — Reuse kb plugin ideas (revalidation frontmatter, consumer lenses) without coupling the projects

**Context.** The owner's existing Claude Code kb plugin contributes two mature mechanisms: volatility-driven revalidation frontmatter (`volatility`, `revalidate_at`, `revalidate`) and consumer-specific views (neutral canon plus `*-reference.md` lenses). The wiki could be built as new domains inside the kb system (immediate consumer synergy through its registry and scope_mappings), or as an independent project.

**Decision.** Independent project. The wiki adopts the revalidation frontmatter wholesale (with volatility defaults per page type) and the lens *concept* for future consumers, but is free to diverge from any kb pattern whenever the wiki's scope is better served.

**Rationale.** Merging would couple an experimental system to a working production tool: every wiki schema experiment would risk breaking kb consumers, and kb's constraints (line caps, template set, registry semantics) would pre-empt wiki design decisions before the wiki has earned its own structure. Independence keeps the blast radius of iteration at zero. The two borrowed ideas are adopted on merit, not for compatibility — revalidation solves the one lint dimension Karpathy leaves entirely unspecified (stale claims, acute in a high-volatility solutions domain where half the analyzed tools are v0.x), and the neutral-canon-plus-lens structure answers "who is a page for" without duplicating knowledge. No lens files ship in v1: the only launch consumer is "Claude answering questions," and the neutral pages are that lens (earn-your-structure applied to views).

**Consequences.** Possible convention divergence between the projects, accepted knowingly. A future merge, if ever warranted, is a migration task — made easier, not guaranteed, by the shared frontmatter semantics.

---

## ADR-011 — Retrieval evaluation harness deferred to a future iteration

**Context.** Jay E's "make it prove itself" principle argues for a benchmark from day one: fixed real questions, both retrieval paths, token/time/correctness comparison. Building it requires the owner to author 10–15 genuine questions and the harness tooling before any wiki exists to query.

**Decision.** Defer the formal harness. Ship both retrieval paths (ADR-009), rely on informal observation initially, and activate the harness in a later iteration — re-runnable at growth milestones, logging to `_reports/retrieval.csv`.

**Rationale.** Sequencing, not disagreement: the principle is accepted, its timing adjusted. A day-one benchmark would measure the floor-effect regime where the outcome is already predicted (Path A wins while the index is small) and would front-load work that blocks nothing. The harness's second function — stress-testing the taxonomy (a question unanswerable by traversing the page types indicates a schema defect) — is more valuable once there is a populated taxonomy to stress. The deferral is bounded: the harness design is fully specified in the spec (§11) so activation is a decision, not a design task.

**Consequences.** The Path A/B verdict waits for data. Risk accepted: informal impressions may mislead in the interim; mitigated by the observability seed (health and retrieval CSVs) capturing data from the start.

---

## ADR-012 — Scope: solutions research now, extensible schema for growth

**Context.** The wiki could launch as a general-purpose knowledge layer for anything the owner reads, or as a focused solutions-research base (tools, patterns, architectures — the domain of the ten existing distillates).

**Decision.** Focused scope at launch, with extensibility as a schema requirement: five page types (Solution, Concept, Technology, Pattern, Person/Org), new types added only when three real instances exist, lenses and general domains deferred to the backlog.

**Rationale.** A focused domain permits rich, opinionated page templates — the same property that makes the solution-sumarizer's output strong — while a general-purpose launch would force loose conventions that serve every domain poorly. Milo's "earn your structure" principle generalizes cleanly from folders to schema: premature generality is the same failure as premature hierarchy. The growth intent is real (the eventual Ideaverse synergy demands it), so it is honored where it is cheap — extension mechanisms designed in from day one — rather than where it is expensive — speculative structure built before need.

**Consequences.** The v1 schema can be sharp and specific. Future domains may require schema evolution, which ADR-004 makes tractable: with a sole machine author and a versioned `WIKI.md`, convention migrations can be executed wiki-wide by the LLM itself under a lint-verified pass.

---

## Cross-cutting rationale: the shape of the whole

Read together, the twelve decisions implement one thesis extracted from the corpus analysis: **the systems that work delegate bookkeeping to the machine, keep retrieval deterministic until scale forces otherwise, and earn every piece of structure from real pressure.** ADRs 1, 2, and 4 establish who owns and reads what; 3 and 6 define how knowledge enters and is found; 7 and 8 make maintenance automatic but bounded; 9, 11, and 12 sequence ambition behind evidence; 5 and 10 keep the system local, independent, and inspectable. The recurring rejected alternative across nearly every record is the same one: doing more, earlier, on anticipation rather than measurement.
