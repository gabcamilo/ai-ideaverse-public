# LLM Wiki — Architecture Decision Records

**Format:** consolidated ADR log (Nygard style: Context → Decision → Rationale → Consequences).
**Scope:** decisions made during the design interview of 2026-07-28, cross-referenced with the ten analyzed reference solutions.
**Companion document:** `llm-wiki-spec.md` (the specification these decisions produced).

All records are **Accepted** unless marked otherwise. Reference solutions are cited by short name in the records — Karpathy's LLM Wiki pattern [R1], the Jay E | RoboNuggets Second Brain [R2], QMD [R3], GBrain [R4], CodeGraph [R5], Graphify [R6], Hermes Agent [R7], Ideaverse/ACE and Architect & Gardener (Nick Milo) [R8, R9], PKM Observability & AI Dreaming (Nicole van der Hoeven) [R10]. These short names are defined terms of this document; full citations to the primary sources (not the project's internal distillates) are in the **References** section at the end.

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

**Status: Accepted, partially amended by ADR-014** (the gold question set is un-deferred to v0.5 and upgraded to include expected pages; harness tooling remains deferred).

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

## ADR-013 — Wiki adoption is enforced by gated push-injection and telemetry, not advisory instruction

**Context.** The v0.1 design ensures agents use the wiki through a routing note in `CLAUDE.md` — an advisory instruction. LLMs demonstrably drift from memory-file instructions as context pressure grows, and every future consumer (subagents, other sessions) would need to independently remember to consult the index. An instruction that must be remembered is a probabilistic guarantee; the project's own thesis (delegate bookkeeping to deterministic mechanisms) argues against relying on one for its most important behavior. Options considered: (a) advisory-only status quo, optionally with telemetry to observe drift; (b) always-on push-injection — a `UserPromptSubmit` hook runs the wikiq scorer against every prompt and injects the top-k index hits into context unconditionally; (c) gated push-injection — the hook always runs wikiq but injects only when the top score clears a relevance threshold; (d) forcing all wiki access through an MCP server interface.

**Decision.** Gated push-injection (c), chosen by the owner, plus two supporting mechanisms: access telemetry (`PreToolUse`/`PostToolUse` hooks logging every Read/Grep/Glob on page directories to a trace file) and explicit wiki-consultation clauses in every consumer subagent definition. The advisory routing note remains, but as documentation of the mechanism rather than the mechanism itself.

**Rationale.** Push-injection flips retrieval from pull to push: the agent no longer has to remember to consult the wiki, because candidate evidence (id, path, one-line summary — index entries only, no pages opened) is already in context when it starts reasoning. Its only remaining decision is which pages to open — a decision it is good at when candidates are in front of it, unlike the decision to go looking, which it is unreliable at. This is the pre-commit-hook philosophy applied to retrieval: don't trust, gate. Always-on (b) was rejected because it taxes every turn — including turns with no wiki relevance — with a few hundred injected tokens; the threshold gate preserves determinism while driving the tax to near-zero on irrelevant prompts. Advisory-only (a) was rejected as the failure mode this ADR exists to eliminate; telemetry alone observes drift without correcting it. The MCP interface (d) was rejected under ADR-005's infrastructure minimalism — it adds a server process to solve a problem a hook solves with a script. Telemetry is retained not for enforcement but for observability: it produces the ground-truth record of actual retrieval behavior that ADR-014's metrics consume, and lets deep lint mechanically detect anti-patterns (grep-first violations; wiki-relevant answers produced with zero wiki reads).

**Consequences.** wikiq becomes a hot path executed on every prompt — it must stay dependency-free and fast, and its scoring quality now affects every turn, not just explicit queries. The injection threshold becomes a tunable pending decision with a documented default. The trace file joins `_reports/` and is consumed by deep lint and the ADR-014 metrics. Subagent definitions acquire a mandatory wiki clause, checked at review.

---

## ADR-014 — Retrieval efficiency is measured by query traces, a utilization ratio, an escalation budget, and miss auditing

**Context.** Two retrieval failure modes threaten the system's value proposition: *bloat* (the agent opens more pages than the answer needs, inflating context) and *miss* (the agent stops short of pages that were relevant). Nothing in v0.1 measures either. The decisive asymmetry: bloat is measurable without ground truth (compare what was opened against what was used), while misses fundamentally require knowing what *should* have been retrieved — ground truth that only a human-authored gold set provides. ADR-011 had deferred the entire evaluation harness, including that gold set.

**Decision.** Four mechanisms. (1) **Query traces:** every `/wiki-query` run appends a structured record to `_reports/queries.jsonl` — question, wikiq's ranked candidates, pages actually opened (from ADR-013 telemetry), pages actually cited in the answer, token cost. (2) **Utilization ratio:** cited ÷ opened, computed per query and in aggregate by deep lint; a low or declining ratio is the mechanical signature of bloat. (3) **Escalation budget** in the query contract: open the top scorer first; each additional page requires the previous one to have failed to answer; a soft ceiling (default 5) beyond which the agent must state its justification in the trace. (4) **Miss auditing:** every "wiki cannot answer" response is logged; deep lint audits that log against the index, and where an existing page plainly covers the question, files a *missed-retrieval* finding — with the corrective action targeted at index metadata (aliases, keywords, summary), since most misses are index-enrichment defects rather than scorer defects. Additionally, ADR-011 is partially amended: the gold question set is authored at v0.5 rather than "someday," and upgraded from question→answer to **question→expected-pages**, so it measures recall directly; harness runner tooling remains deferred.

**Rationale.** The bloat side needs no gold data, so it ships fully automated: the utilization ratio plus the escalation budget give both a detector and a preventer, in the Jay E spirit of climbing a ladder one rung at a time rather than reading broadly on speculation. The miss side is handled honestly rather than cosmetically: proxy detection (the no-answer audit) catches the detectable subset without gold labels, and the gold set — the only true recall instrument — is pulled earlier because ADR-013's push-injection makes retrieval quality load-bearing on every turn, raising the cost of flying blind. Routing miss corrections into index metadata closes a compounding loop consistent with the project thesis: miss detected → index enriched → future recall improves through the same lint machinery already built, making the index self-tuning. The alternative — treating misses as scorer bugs and iterating on wikiq's algorithm — was rejected as the default response because it optimizes the harder-to-change component against the noisier signal; the scorer is only revisited if miss findings persist after metadata enrichment.

**Consequences.** `queries.jsonl` becomes the canonical retrieval record (the earlier `retrieval.csv` is retained only for milestone harness comparisons). Deep lint gains finding categories (missed-retrieval, low-utilization, grep-first violation, ceiling-exceeded) and `health.csv` gains aggregate columns for utilization and miss counts. The query command's contract grows the escalation budget and trace emission. The owner acquires a scheduled authoring obligation: the gold question set at v0.5.

---

## ADR-015 — Governance dashboard as a generated, read-only projection, wiki-scoped

**Context.** The "Second Brain" system presented by the YouTube channel Jay E | RoboNuggets [R2] — a Claude Code workspace with deterministic retrieval (`brain.js`) and a four-layer visual dashboard ("Rubric": Applications, Routines, Memory, Skills) — demonstrates a workspace-governance surface and supplies its own critique of it: the visual is "30% of the value," decorative graphs (its Obsidian comparison) answer no operational question, and a hand-maintained dashboard "must be kept in sync with actual workspace state; an outdated graph gives false confidence." The project's own ADR-009 rationale had already taken the position that a graph you look at is theater while a graph that answers operational questions is infrastructure. Separately, the owner disclosed the umbrella vision: llm-wiki is one module of **ai-ideaverse**, alongside the Obsidian PKM vault and, eventually, full Claude Code workspace tooling. Options considered for the dashboard: (a) no visual layer; (b) a live dashboard application maintained alongside the wiki; (c) a generated, read-only projection rebuilt from the wiki's existing truth (index, reports, traces); and for scope: wiki-only vs. full-workspace audit à la Jay E.

**Decision.** Build (c), wiki-scoped: a `scripts/build-dashboard.mjs` that reads `_index.yaml`, the link graph, `health.csv`, and the v0.5 traces, and emits a single self-contained `_reports/dashboard.html` — regenerated by every deep lint run and on demand via `/wiki-status --visual`. Four panels mapped from Jay E's model onto the wiki's own layers: **Pages** (his Memory — the knowledge graph, colored by type, sized by inbound, stale halos, orphan flags), **Sources** (his Applications — ingest registry with origin liveness as recorded by the ADR-016 mechanism: alive/dead/moved, `unverified` shown honestly when no data exists), **Operations** (his Skills — commands, agent, scripts and what each touches), **Automations** (his Routines — cron and hooks with last-run status). A consumption **heat overlay** from `queries.jsonl`/`access-trace.jsonl` distinguishes cited-warm, opened-never-cited-cool, and untouched-grey pages. Full-workspace scope is explicitly deferred to a separate feature of the ai-ideaverse umbrella project.

**Rationale.** The strict incorporation test — every element must answer an actionable question (what to prune, what's stale, what's unused, what's drifting) — is inherited from Jay E's own 30/70 lesson and from ADR-009's theater/infrastructure line. The generated-projection form dissolves his stated maintenance weakness by construction: nothing edits the dashboard, nothing trusts it as a source, deleting it loses nothing, and it cannot drift because it is derived from the same artifacts lint already keeps honest. A live application (b) was rejected under ADR-005 (no server processes) and because it would create a second surface competing with the index for truth. No visual layer (a) was rejected because the wiki already pays for the data that makes governance questions answerable — the rendering is marginal cost — and because the v0.5 consumption traces enable something the reference system lacks: the dashboard shows not just what exists but what is *alive*. Full-workspace scope was rejected *for this module* because it reaches outside the repo's truth boundary and needs its own scanners; under the ai-ideaverse umbrella it belongs to a sibling feature that composes module-published data (this dashboard's underlying JSON among them) rather than to the wiki itself. Modules keep their truth boundaries; the umbrella aggregates.

**Consequences.** The dashboard build becomes a deep-lint post-step and a v0.6 deliverable (Phase 10). The build script should emit both the HTML and a machine-readable `dashboard-data.json`, which doubles as the wiki's published governance interface for the future workspace-level surface — designed once, consumed twice. Rendering must stay self-contained and offline (vendored or hand-rolled visualization, no runtime CDN). The workspace-scope feature, when designed, gets its own ADR under the umbrella project.

---

## ADR-016 — Provenance is enforced programmatically: validated chain, tiered attribution, owned liveness

**Context.** The provenance chain (page frontmatter `sources[]` → distillate → distillate frontmatter `origin_urls` → primary source) existed structurally from ADR-003 but was only partially enforced, and a design review surfaced three defects. First, the page→distillate edge was declared but never validated — the validator checked that the `sources` key existed, not that its entries resolved; a typo'd path would pass every gate, and origin URLs lived in two places (distillate and registry) with no agreement check, while the registry's `pages_touched` (an ingest-time snapshot) silently diverged from the living page-frontmatter edges. Second, provenance stopped at page level: on cross-source pages no individual claim identified its source, which became untenable once the adversarial ingest (plan 5.7) required contradiction adjudications to be recorded "with attribution" — a mechanism that didn't exist — and which weakened revalidation (an origin changes; which claims are affected?). Third, an outright contradiction: ADR-015 promised dead-origin flags on the dashboard while D3 denies the lint agent network access and no other component owned origin liveness — the flag could never light up.

**Decision.** Three mechanisms. (1) **Validated chain:** validator checks V7 (every page `sources[]` entry resolves to a real distillate and registry entry; registry `origin_urls` must byte-match distillate frontmatter, the immutable distillate being canonical; a computed `derived_pages` field per registry entry is recomputed like `inbound`, demoting `pages_touched` to an uncorrected historical record) and V8 (every inline attribution key resolves to the page's own declared sources). (2) **Tiered attribution**, written into WIKI.md: ordinary synthesis inherits page-level `sources` silently; quantitative claims, benchmark figures, and any claim surviving a contradiction adjudication must carry a footnote-style key (`[^source-id]`) — machine-parseable, so lint can enumerate all claims touched by a given source. (3) **Owned liveness:** a deterministic `check-origins.mjs` performs HEAD checks against registry origins, run weekly by the cron *wrapper* before the lint session launches; every Deepen run (an already-legitimate, human-triggered network context) opportunistically writes `origin_status` + `last_verified` as a side effect. The lint agent itself never gains network access; unknown states render as `unverified`.

**Rationale.** The chain fix follows the project's oldest lesson (ADR-006): a declared-but-unvalidated invariant is the worst defect class, because it fails silently on exactly the edge Deepen and revalidation depend on. Making the immutable distillate canonical for origin URLs resolves the two-copies problem by fiat rather than synchronization. Tiered rather than universal attribution is earn-your-structure applied to provenance: sentence-level citation everywhere would tax every page's token cost for LLM readers and add a brittle maintenance surface, while attribution *only where numbers or disagreement make it load-bearing* delivers the queryability that adjudication and revalidation actually need. The liveness split respects the trust architecture precisely: D3's boundary exists to keep an autonomous LLM away from the network, and neither proposed component violates it — the wrapper's HEAD checks involve no LLM judgment at all, and Deepen's writes occur in a context a human already opened. The rejected alternative of simply widening D3 would have traded a clean boundary for convenience.

**Consequences.** The validator gains V7/V8 and a `--fix-derived` mode; micro-lint's checklist gains the attribution-resolution check; the sources registry gains `origin_status`, `last_verified`, and `derived_pages` fields; the cron wrapper gains a pre-lint step; the dashboard's Sources panel renders liveness honestly, including its absence. Adjudicated contradictions become permanently traceable to their sources. Status semantics are conservative: `dead` requires confirmed absence (404/410/DNS failure on repeat checks), while blocked or ambiguous responses (403, 429, robots-policy refusals, timeouts) map to `unverified` — automated-access filtering, common on major hosts, must never be misread as source death. One accepted limitation: liveness data is only as fresh as the last wrapper run or Deepen touch — `unverified` and stale `last_verified` values are displayed, not hidden.

---

## Cross-cutting rationale: the shape of the whole

Read together, the twelve founding decisions implement one thesis extracted from the corpus analysis: **the systems that work delegate bookkeeping to the machine, keep retrieval deterministic until scale forces otherwise, and earn every piece of structure from real pressure.** ADRs 1, 2, and 4 establish who owns and reads what; 3 and 6 define how knowledge enters and is found; 7 and 8 make maintenance automatic but bounded; 9, 11, and 12 sequence ambition behind evidence; 5 and 10 keep the system local, independent, and inspectable. The recurring rejected alternative across nearly every record is the same one: doing more, earlier, on anticipation rather than measurement. ADR-013 and ADR-014 extend the same thesis to the wiki's consumption side: adoption is gated by mechanism rather than trusted to instruction, bloat is measured where no ground truth is needed, and the one instrument that genuinely requires human input — the gold question set — is scheduled rather than indefinitely deferred. ADR-015 closes the loop on the governance side: the visual layer is admitted only as a read-only projection of truth the system already maintains, and anything beyond the module's truth boundary is deferred to the ai-ideaverse umbrella it belongs to. ADR-016 applies the founding lesson recursively to provenance itself: an invariant is only real once a validator enforces it, attribution precision is earned where disagreement makes it load-bearing, and even origin liveness gets an owner without ever loosening the lint agent's network boundary.

---

## References

Primary sources. The project's `sources/` distillates are derived summaries of these and are not citable as sources themselves.

| # | Source | Author | Type | URL |
|---|---|---|---|---|
| R1 | *LLM Wiki: A Pattern for Personal Knowledge Bases* | Andrej Karpathy | GitHub gist | https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f |
| R2 | *Build your Ultimate Second Brain with Claude Fable 5 (before it's too late)* | Jay E \| RoboNuggets | YouTube video (13:41) | https://www.youtube.com/watch?v=VoKiKvgpk78 |
| R3 | *qmd (Query Markup Documents)* | Tobi Lütke | GitHub repository | https://github.com/tobi/qmd |
| R4 | *GBrain* (analyzed via `llms-full.txt`) | Garry Tan | GitHub repository | https://github.com/garrytan/gbrain · https://raw.githubusercontent.com/garrytan/gbrain/master/llms-full.txt |
| R5 | *CodeGraph* | colbymchenry | GitHub repository | https://github.com/colbymchenry/codegraph |
| R6 | *Graphify* | Safi Shamsi / Graphify Labs | GitHub repository | https://github.com/graphify-labs/graphify |
| R7 | *Hermes Agent* | Nous Research | GitHub repository + docs | https://github.com/nousresearch/hermes-agent · https://hermes-agent.nousresearch.com/docs/developer-guide/architecture |
| R8 | *Create Your Digital Home: Obsidian Walkthrough* (Ideaverse for Obsidian) | Nick Milo, Linking Your Thinking | YouTube video | https://www.youtube.com/watch?v=bVl3IRGOWvk |
| R9 | *This Secret Principle Will Transform Your Notes* (Architect & Gardener, PKM Summit NL 2025) | Nick Milo, Linking Your Thinking | YouTube video | https://www.youtube.com/watch?v=q0pQh69iPWA&list=PLw1ExsV_HfJ6r6I3VF-xeF4PtYiXA-8gF |
| R10 | *Do Androids Dream of Second Brains?: Observability and AI for PKM* (PKM Summit Utrecht, 43 min) | Nicole van der Hoeven | YouTube video | https://www.youtube.com/watch?v=BeuaPO0Ezuk |
| R11 | *solution-sumarizer* | Gabriela Camilo | GitHub repository | https://github.com/gabcamilo/solution-sumarizer |
| R12 | *ai-ideaverse-public* (project working repository, public copy) | Gabriela Camilo | GitHub repository | https://github.com/gabcamilo/ai-ideaverse-public |
| R13 | *AI Knowledge & Context Management: Six Concepts Compared* | project owner (research doc, 2026-07-22) | internal document | adversarial ingest fixture (plan C26); its own references resolve to R1, R3–R7 |
| R14 | *mermaid-diagram* (designated renderer for future human-lens diagram projections; SPEC §12 backlog) | Gabriela Camilo | GitHub repository | https://github.com/gabcamilo/mermaid-diagram |
