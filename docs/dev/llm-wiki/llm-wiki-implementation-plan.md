# LLM Wiki — Implementation Plan

**Status:** Draft v0.1 · 2026-07-28
**Audience:** an executing agent (Claude Code or similar) that does NOT share the design background. Everything needed is in this file plus the two companion documents. Do not improvise beyond what a step permits.
**Companion documents (read both before starting):**
- `llm-wiki-spec.md` — the specification (referenced as SPEC §n)
- `llm-wiki-adr.md` — the decision records with rationale (referenced as ADR-nnn)

---

## 0. How to execute this plan

1. Work through phases in order. Do not start a phase until the previous phase's **Validation gate** passes completely.
2. Steps marked **[HUMAN]** require input or approval from the project owner. Stop and ask; do not substitute a guess. (Phases 1–8 deliver v0.1–v0.4 and end at handover; Phase 9 is the v0.5 iteration and may be executed as a separate engagement.)
3. Steps marked **[DECISION Dn]** touch a pending decision listed in §3. Follow the decision's *default* unless the human has resolved it otherwise.
4. Every phase ends with a git commit using the message given. Never batch multiple phases into one commit.
5. If any validation fails, fix it within the current phase before proceeding. If a fix would contradict SPEC or an ADR, stop and ask the human.
6. The prime invariant of the entire system (SPEC §6, ADR-006): **`_index.yaml` is updated in the same operation as any page write.** If you ever write a wiki page without updating the index, you have introduced the system's worst defect class. The validator built in Phase 2 exists to catch this — run it liberally.

---

## 1. Component inventory — what gets built and its role in the architecture

Every artifact below maps to a layer of SPEC §4. Build nothing that is not on this list without human approval (ADR-012: structure is earned, not anticipated).

| # | Artifact | Kind | Architecture role | Built in |
|---|---|---|---|---|
| C1 | `llm-wiki/` git repository | repo | Container for all layers | Phase 1 |
| C2 | `WIKI.md` | schema document | Schema layer core: the LLM maintainer's job description — conventions, page schemas, operation workflows, whitelists (SPEC §4, ADR-004) | Phase 1, finalized Phase 2 |
| C3 | `CLAUDE.md` (repo root) | Claude Code memory file | Retrieval layer entry point: routing note directing every session to index-first retrieval and to `WIKI.md` (SPEC §7) | Phase 4 |
| C4 | `_index.yaml` | structured index | Canonical index: pages registry + sources registry; serves Path A, Path B, and audit lookup (SPEC §6, ADR-006, ADR-007) | Phase 1 |
| C5 | `sources/` | directory of distillates | Raw-sources layer: immutable solution-sumarizer outputs (SPEC §4.1, ADR-003) | Phase 3 |
| C6 | `solutions/ concepts/ technologies/ patterns/ people/` | page directories | Wiki layer: the five page types (SPEC §5, ADR-012) | Phase 2–3 |
| C7 | `_templates/` | page templates | Schema layer: extracted from real pages, never designed in the abstract (SPEC §14 Q1, ADR-012) | Phase 2 |
| C8 | `scripts/validate-index.mjs` | deterministic script | Enforcement of the index invariant; used by micro-lint, deep lint, and the git hook | Phase 2 |
| C9 | `.claude/commands/wiki-ingest.md` | slash command | Operation: Ingest (SPEC §8.1) | Phase 3 |
| C10 | `.claude/commands/wiki-query.md` | slash command | Operation: Query (SPEC §8.2) | Phase 4 |
| C11 | `.claude/commands/wiki-lint.md` | slash command | Operation: Lint, micro and deep modes (SPEC §8.3, ADR-008) | Phase 5 |
| C12 | `.claude/commands/wiki-deepen.md` | slash command | Operation: Deepen (SPEC §8.4, ADR-003) | Phase 6 |
| C13 | `.claude/commands/wiki-status.md` | slash command | Convenience: wiki health at a glance (SPEC §9) | Phase 5 |
| C14 | `.claude/agents/wiki-deep-linter.md` | subagent definition | Isolated context for the whole-wiki deep lint pass, so lint reasoning does not pollute the main session and gets a clean token budget (ADR-008) | Phase 5 |
| C15 | `scripts/wikiq.mjs` | deterministic script | Retrieval Path B: index scorer, no model calls (SPEC §7, ADR-009) **[DECISION D4]** | Phase 4 |
| C16 | `.git/hooks/pre-commit` (installed via `scripts/install-hooks.sh`) | git hook | Deterministic guard: refuses commits that violate the index invariant or frontmatter schema | Phase 2 |
| C17 | Claude Code `PostToolUse` hook (`.claude/settings.json`) | Claude Code hook | Soft guard: after any Write/Edit inside page directories, runs C8 and surfaces failures immediately in-session | Phase 5 |
| C18 | `_reports/` + `scripts/append-health.mjs` | reports dir + script | Observability seed: lint reports, `health.csv`, `retrieval.csv` (SPEC §10) | Phase 5 |
| C19 | cron entry running `claude -p` | scheduled job | Weekly deep lint, report-first (SPEC §9, ADR-008) **[DECISION D5]** | Phase 7 |
| C20 | solution-sumarizer SKILL.md | external skill (exists) | Ingestion front door; its output contract is an interface of this system (ADR-003) | consumed from Phase 3 |
| C21 | `scripts/inject-context.mjs` + `UserPromptSubmit` hook entry | Claude Code hook | Adoption enforcement: runs wikiq on every prompt, injects top-k index hits when the top score clears the D8 threshold (SPEC §7, ADR-013) | Phase 9 |
| C22 | `PreToolUse`/`PostToolUse` telemetry hook entries + `scripts/log-access.mjs` | Claude Code hooks | Retrieval observability: logs every Read/Grep/Glob on page directories to `_reports/access-trace.jsonl` (ADR-013) | Phase 9 |
| C23 | `_reports/queries.jsonl` conventions (emitted by C10) | trace log | Canonical per-query record: candidates, opened, cited, tokens → utilization ratio (ADR-014) | Phase 9 |
| C24 | `gold/questions.yaml` | gold data **[HUMAN]** | Recall ground truth: question → expected page ids; schema stress test (SPEC §11, ADR-014) | Phase 9 |
| C25 | `scripts/build-dashboard.mjs` → `_reports/dashboard.html` + `_reports/dashboard-data.json` | generated projection | Governance dashboard: four panels + heat overlay, read-only, rebuilt by deep lint; the JSON doubles as the wiki's published interface for the future ai-ideaverse workspace surface (ADR-015) | Phase 10 |
| C26 | `sources/ai-knowledge-concepts.md` | external distillate | Adversarial ingest fixture: a comparative analysis NOT produced by solution-sumarizer, containing claims that partially contradict existing pages — exercises lint's contradiction detection | Phase 5 |
| C27 | `scripts/check-origins.mjs` | deterministic script | Origin liveness: cheap HEAD requests against every registry `origin_urls`, writing `origin_status` + `last_verified` into the sources registry; run by the cron wrapper OUTSIDE the sandboxed lint agent, and enriched opportunistically by Deepen runs. `dead` only on confirmed 404/410/DNS failure across repeat checks; 403/429/robots refusals/timeouts → `unverified` (D11, ADR-016) | Phase 7 |

Explicitly NOT built in v1 (deferred by ADR/SPEC — do not create these): consumer lens files, semantic-search/QMD tier, harness runner tooling over the gold set (the gold set itself IS built, in Phase 9), Ideaverse bridge, `log.md`, any sixth page type, `wiki_hints` summarizer changes.

---

## 2. Prerequisites — verify before Phase 1

P1. Claude Code installed and authenticated; `claude -p "ok"` returns successfully from a shell.
P2. Node.js ≥ 20 available (`node --version`) — needed for C8/C15/C18 scripts.
P3. Git installed; ability to create a new local repository.
P4. **[HUMAN]** Obtain from the owner: (a) the solution-sumarizer SKILL.md or at minimum a sample of its output frontmatter contract; (b) the location of the ten existing distillate files (the reference corpus); (c) confirmation of where `llm-wiki/` should live on disk.
P5. **[HUMAN]** Confirm cron (or an equivalent scheduler) is acceptable on this machine for Phase 7.

**Validation gate:** all five items checked; the ten distillates are readable; each distillate has YAML frontmatter containing at least `title`, `solution.name`, `sources[].url`, and `tags`.

---

## 3. Pending decisions register

Consult this table whenever a step is marked [DECISION Dn]. "Default" is what you do if the human has not decided; "Blocks" tells you when you must raise it at the latest.

| ID | Question | Default (use unless overridden) | Blocks at | Origin |
|---|---|---|---|---|
| D1 | Heading vocabulary per page type | Resolved by the Phase 2 procedure (extract from two real pages); human approves result | Phase 2 gate | SPEC §14.1 |
| D2 | Typed-relationship vocabulary for `## Relationships` | Start with exactly: `uses`, `used-by`, `alternative-to`, `built-by`, `implements-pattern`, `implemented-by`, `related-to`. Lint reports any other type as a finding; humans add types via WIKI.md edits | Phase 2 gate | SPEC §14.2 |
| D3 | May deep lint call Deepen autonomously (network access to origin URLs)? | NO — deep lint only queues deepen tasks in its report; Deepen runs are human-triggered | Phase 5 | SPEC §14.3 |
| D4 | wikiq implementation language | Plain Node.js ESM (`.mjs`), zero dependencies | Phase 4 | SPEC §14.4 |
| D5 | Deep lint schedule (day/time) | Sundays 03:00 local | Phase 7 | SPEC §9 |
| D6 | Does Query's file-back (SPEC §8.2) auto-commit? | Yes, commits with `wiki(query): …`; human reviews via git log | Phase 4 | new |
| D7 | Are the ten distillate files copied into `sources/` or referenced in place? | Copied in (immutability requires the wiki owning its raw layer) | Phase 3 | new |
| D8 | Push-injection relevance threshold | Inject when the top wikiq score ≥ 6 points; k = 3 entries; constant defined at the top of `inject-context.mjs`; tune from trace data | Phase 9 | ADR-013 |
| D9 | Escalation budget soft ceiling (pages opened per query) | 5; exceeding requires a justification field in the query trace | Phase 9 | ADR-014 |
| D10 | Dashboard rendering technology | Single self-contained HTML file; hand-rolled canvas/SVG force layout or a vendored single-file library copied into `scripts/vendor/` — no runtime CDN, no server, no build step | Phase 10 | ADR-015 |
| D11 | Origin liveness mechanism | Deterministic HEAD checks via `check-origins.mjs`, run weekly by the cron wrapper (before lint) + opportunistic status writes from every Deepen run; the lint agent itself NEVER gains network access (D3 unchanged). **Status semantics:** `dead` means confirmed gone (404/410 or DNS failure on repeat checks); blocked or ambiguous responses (403, 429, robots-style refusals, timeouts) map to `unverified`, never `dead` — bot-filtering is common (e.g. GitHub's robots policy) and must not be misread as source death. Unknown states rendered honestly as `unverified` | Phase 7 | ADR-016 |

---

## 4. Phase 1 — Repository bootstrap and WIKI.md first draft

**Goal:** the container exists; the LLM maintainer has a written job description.

1.1 Create the repository at the location from P4(c): `git init llm-wiki`, default branch `main`.

1.2 Create the directory skeleton exactly as SPEC §4.2: `sources/ solutions/ concepts/ technologies/ patterns/ people/ _templates/ _reports/ scripts/ .claude/commands/ .claude/agents/`. Add a `.gitkeep` in each empty directory.

1.3 Create `_index.yaml` with empty registries:

```yaml
# Canonical index. INVARIANT: updated in the same operation as any page write.
# Consumed by: Path A (direct read), Path B (scripts/wikiq.mjs), audit lookups.
pages: []
sources: []
```

1.4 Author `WIKI.md` v1. This is the single most important artifact (ADR-004: with a sole machine author, this document is the only thing standing between coherence and drift). It MUST contain these sections, in this order, written as direct instructions to a maintainer LLM:

  1. **Identity and mission** — "You are the sole author and maintainer of this wiki. Primary readers are LLMs (ADR-002). You compound knowledge; you never discard work."
  2. **The prime invariant** — index updated with every page write, verbatim from §0.6 of this plan.
  3. **Layer map and mutability contract** — reproduce SPEC §4 table; state that `sources/` is immutable after ingest and `WIKI.md`/templates change only with human approval.
  4. **Page taxonomy** — the five types with one-line definitions and their directory (SPEC §5); the rule that new types require three real instances and human approval.
  5. **Atomicity rules** — verbatim from SPEC §5.1 (answer-unit, 50–250 lines, promotion pressures, anchors, no stubs, aliases instead).
  6. **Frontmatter schema** — verbatim from SPEC §5.2, plus volatility defaults per type (Solution: high, Technology: medium, Concept/Pattern: low, Person: low) and the revalidate_at intervals: high = +3 months, medium = +6 months, low = +12 months, static = never.
  7. **Body conventions** — machine-first rules from SPEC §5.3, with the D1 heading vocabulary marked `TO BE FILLED IN PHASE 2` and the D2 relationship vocabulary inserted from §3. Include the **tiered attribution rule**: ordinary synthesis inherits the page's `sources` frontmatter silently; quantitative claims, benchmark figures, and any claim that survived a contradiction adjudication MUST carry an inline footnote-style attribution key (`[^source-id]`) resolving to an entry in that page's `sources[]` list (validator check V8). Precision only where numbers or disagreement make provenance load-bearing.
  8. **The four operations** — Ingest, Query, Lint, Deepen: trigger, step list, bounded scope, output, commit format, exactly as SPEC §8. Include the micro-lint checklist (see Phase 3, step 3.2) and the deep-lint auto-fix whitelist verbatim: auto-fix = broken internal links, index drift, missing reciprocal links, frontmatter mechanical errors; report-only = contradictions, staleness resolutions, merges/splits/promotions, deletions (ADR-008).
  9. **Commit conventions** — SPEC §8.5 formats; commits are load-bearing (ADR-007).
  10. **What you must never do** — write a page without updating the index; modify `sources/`; create lens files, new page types, or new top-level structure without approval; delete anything outside a human-approved lint finding; invent relationship types outside D2's list.

1.5 Copy `llm-wiki-spec.md` and `llm-wiki-adr.md` into the repo root (they are project documentation and give any future agent the background this plan assumes). **Documentation convention, binding for all project documents created from here on:** every document that names an external system, pattern, or person must carry a References section citing the primary source (URL, author, type) — the actual origin, never a `sources/` distillate. At wiki-page level this rule is already mechanized by the `sources` frontmatter and the index's sources registry; WIKI.md section 9 must state both halves of the convention.

**Validation gate:**
- [ ] Repo exists, skeleton matches SPEC §4.2 exactly (no extra dirs).
- [ ] `WIKI.md` contains all ten sections; sections 5, 6, 8 quote SPEC verbatim where instructed.
- [ ] `_index.yaml` parses as YAML (`node -e "require('yaml')"` is NOT available with zero deps — validate with `node --experimental-strip-types` alternatives is overkill: simply `python3 -c "import yaml,sys; yaml.safe_load(open('_index.yaml'))"` or visual check; the real parser arrives in Phase 2).
- [ ] Commit: `wiki(bootstrap): repo skeleton + WIKI.md v1 + empty index`

---

## 5. Phase 2 — Two real pages, extracted templates, and the validator

**Goal:** resolve D1 by practice; make the index invariant machine-enforced.

2.1 Pick two distillates from the corpus: `qmd` (a Solution) and, from its content, the concept `hybrid search`. **First copy the qmd distillate into `sources/qmd.md`** and add its sources-registry entry with `ingested: null` (pending — the full ingest happens in 3.3): the pages authored next will declare `sources: ["sources/qmd.md"]` in frontmatter, and validator check V7 requires that path and registry entry to exist. Then manually author (do not run the not-yet-existing ingest command) two pages:
  - `solutions/qmd.md`
  - `concepts/hybrid-search.md`
  Follow WIKI.md's frontmatter schema and body conventions. Write real content from the distillate. Include a `## Relationships` section in each, using only D2 types, and make the QMD↔hybrid-search links reciprocal.

2.2 While writing, converge on the heading vocabulary (D1). Requirements: fixed per type, stable (they become anchor targets), machine-greppable. Starting proposal to refine, not to accept blindly:
  - Solution: `## What it is` · `## Problem it solves` · `## How it works` · `## Relationships` · `## Assessment`
  - Concept: `## Definition` · `## Why it matters` · `## Variants and mechanics` · `## Relationships`
  Adjust only if the two real pages demonstrate a need. **[HUMAN]** Present the final vocabulary for approval, then write it into WIKI.md section 7, removing the `TO BE FILLED` marker.

2.3 Extract `_templates/solution.md.template` and `_templates/concept.md.template` from the two finished pages: replace content with `{placeholders}`, keep frontmatter keys and headings literal. Do NOT create templates for the other three types yet (ADR-012 / SPEC §14.1: templates are extracted from real pages; Technology/Pattern/Person templates are extracted in Phase 3 after their first pages exist — see 3.6).

2.4 Register both pages in `_index.yaml` (all fields of SPEC §6: id, path, type, title, aliases, summary ≤ 160 chars, keywords, inbound, volatility, updated).

2.5 Build `scripts/validate-index.mjs` (C8). Zero npm dependencies; implement a minimal YAML reader for the restricted subset used by `_index.yaml` and page frontmatter, or vendor a single-file YAML parser into `scripts/vendor/`. The validator MUST check, and exit non-zero listing every violation:
  - V1 Every `.md` file under the five page directories has exactly one `pages[]` entry with matching `path`, and vice versa (no ghost entries, no unindexed pages).
  - V2 Every page's frontmatter parses and contains all required keys of SPEC §5.2 with legal values (type matches its directory; volatility in enum; dates ISO).
  - V3 Every intra-wiki markdown link and every `## Relationships` target resolves to an existing page file or `_index.yaml` alias.
  - V4 Relationship types ⊆ the D2 vocabulary.
  - V5 Every `sources[]` entry's `path` exists under `sources/`, and every file under `sources/` has an entry.
  - V6 `pages[].inbound` equals the actual count of distinct pages linking in (compute from V3's link graph); report mismatches (this check may auto-fix when run with `--fix-inbound`).
  - V7 **Provenance chain integrity:** every page frontmatter `sources[]` entry resolves to an existing file under `sources/` AND a matching sources-registry entry; every registry entry's `origin_urls` byte-matches the corresponding distillate's frontmatter (the distillate is canonical — it is immutable); each registry entry's computed `derived_pages` equals the set of pages whose frontmatter lists that source (auto-fixable with `--fix-derived`; `pages_touched` remains a historical ingest snapshot and is never "corrected").
  - V8 **Attribution keys resolve:** every footnote-style attribution key on a page (`[^source-id]`) maps to an entry in that page's own `sources[]` frontmatter; no dangling keys, no keys pointing outside the page's declared sources.
  Output format: one line per violation, `V<code> <file-or-id>: <message>`, then a summary line `OK` or `FAIL n violations`.

2.6 Build `scripts/install-hooks.sh` which installs C16: a `pre-commit` hook running `node scripts/validate-index.mjs`; commit refused on FAIL. Run it. Verify by deliberately breaking the index (rename a page without editing the index), confirming the commit is refused, then reverting.

**Validation gate:**
- [ ] `node scripts/validate-index.mjs` prints `OK` on the current tree.
- [ ] The deliberate-breakage test above was performed and the hook blocked the commit.
- [ ] WIKI.md section 7 now contains the human-approved D1 vocabulary.
- [ ] Both templates exist and contain no leftover page-specific content.
- [ ] Commit: `wiki(bootstrap): first pages (qmd, hybrid-search), templates, index validator + pre-commit hook`

---

## 6. Phase 3 — The Ingest operation and corpus ingestion

**Goal:** Ingest is a repeatable command; all ten distillates are in the wiki.

3.1 **[DECISION D7]** Copy the remaining nine distillate files into `sources/` with kebab-case filenames (`sources/qmd.md` is already present from 2.1). All ten are now immutable (WIKI.md section 10).

3.2 Author `.claude/commands/wiki-ingest.md` (C9). A slash command file whose body instructs the session, step by step (SPEC §8.1). Required content — write these as imperative instructions inside the command:
  1. Argument: path to a distillate in `sources/` (`$ARGUMENTS`).
  2. Read WIKI.md fully before acting.
  3. Read the distillate. List every entity it mentions that is, or should be, a wiki page or alias — this is the link worksheet.
  4. Perform the **link inversion** (ADR-003 rationale): for each worksheet entity, update or create the concept-shaped page; the distillate's solution page links out to entities, each entity page links back. Typical blast radius 5–15 pages; if it exceeds 20, stop and ask the human.
  5. Apply atomicity rules: prefer sections + index aliases over new small pages (WIKI.md section 5).
  6. Update `_index.yaml`: page entries (new/updated) AND a `sources[]` entry with `id, path, ingested, origin_urls, pages_touched`.
  7. **Micro-lint checklist** (run and self-verify, then run the validator):
     - all links on touched pages resolve;
     - relationships reciprocal where the type implies it (`uses`↔`used-by`, `implements-pattern`↔`implemented-by`);
     - frontmatter complete, volatility defaulted by type, `revalidate_at` computed;
     - headings conform to the D1 vocabulary;
     - quantitative/benchmark claims carry attribution keys that resolve (V8);
     - `node scripts/validate-index.mjs --fix-inbound --fix-derived` prints `OK`.
  8. Commit: `wiki(ingest): <source-id> — <n> pages touched, <m> created`.

3.3 Run `/wiki-ingest` on `sources/qmd.md` FIRST even though its pages partially exist — this validates the command against a known-good baseline (expected result: minor page updates, and the PENDING registry entry from 2.1 completed in place — `ingested` date set, `pages_touched` filled; the entry must be updated, never duplicated). Fix the command file if behavior deviates.

3.4 Ingest the remaining nine distillates ONE AT A TIME, in this order (chosen so shared entities accrete gradually): codegraph, graphify, gbrain, hermes-agent, second-brain-claude-code, llm-wiki, pkm-observability-ai-dreaming, ideaverse-for-obsidian, architect-gardener-framework. After each: validator must print `OK`; commit before starting the next.

3.5 Expected shape after 3.4 (sanity ranges, not hard requirements): 25–60 pages total; `technologies/` contains at least tree-sitter, sqlite-fts5, mcp; `concepts/` at least hybrid-search, knowledge-graph, compounding-memory or equivalent; `patterns/` at least index-first-retrieval and background-consolidation or equivalents; cross-links: sqlite-fts5 and mcp should each have inbound ≥ 3. If the wiki is wildly outside these ranges (e.g., 150 stub pages), the atomicity rules were violated — run a corrective pass before the gate.

3.6 Extract `_templates/technology.md.template`, `pattern.md.template`, `person.md.template` from the best real instance of each type now existing (completing 2.3's deferral).

**Validation gate:**
- [ ] Ten `sources/` files, ten `sources[]` index entries, ten ingest commits.
- [ ] Validator `OK`; no page violates the 50–250 line guidance by more than 50% without a noted reason.
- [ ] Five templates exist.
- [ ] Spot-check (manual, human-reviewable): open `technologies/sqlite-fts5.md` — it must link back to every solution that uses it (per the corpus: QMD, CodeGraph, Hermes at minimum). This is the concept-shaped topology promised by ADR-003; if it is missing, Ingest's link inversion is broken. **[HUMAN]** owner reviews this spot-check.
- [ ] Commit for 3.6: `wiki(bootstrap): remaining templates extracted from real pages`

---

## 7. Phase 4 — Retrieval: Path A routing and Path B scorer

**Goal:** both retrieval paths operational (ADR-009).

4.1 Author `CLAUDE.md` at repo root (C3). Content: (a) one-paragraph statement of what this repo is, pointing to WIKI.md, SPEC, ADR; (b) the routing rule, verbatim: "To answer any question from this wiki: FIRST consult `_index.yaml` — via `node scripts/wikiq.mjs \"<question>\"` when available, else by reading the index directly. Open only the pages the index/scorer indicates. Follow at most one `## Relationships` hop. Never grep or glob across page directories as a first resort."; (c) pointer to the slash commands.

4.2 **[DECISION D4]** Build `scripts/wikiq.mjs` (C15). Contract:
  - Input: the question as argv; optional `--k n` (default 5), `--json`.
  - Algorithm (deterministic, no model calls, no page files opened — Jay E's ladder, SPEC §7):
    1. Lowercase, strip punctuation, drop stopwords (embed a ~50-word English stopword list), keep remaining keywords.
    2. Score every `pages[]` entry: +3 per keyword matching title or aliases (word-boundary match), +2 per keyword in `keywords`, +1 per keyword in `summary`; multiply final score by `1 + 0.1 × min(inbound, 10)` (hub boost).
    3. Output top-k as `score  id  path  "summary"` lines (or JSON with `--json`), plus a final line `open: <path>` for the top scorer.
  - Exit 0 with `no-match` line if the best score is 0.
4.3 Author `.claude/commands/wiki-query.md` (C10), implementing SPEC §8.2: run wikiq with the user's question → read only the indicated page(s) → at most one relationship hop → synthesize the answer FROM WIKI PAGES, never from `sources/` → if the synthesis is novel (not present on any page), file it back into the appropriate page + index update + validator + commit `wiki(query): filed back …` **[DECISION D6: yes, auto-commit]** → if the wiki cannot answer, say so explicitly and name the closest pages plus a proposed ingest/deepen (gap visibility, SPEC §8.2).

4.4 Functional validation (informal, NOT the deferred harness of ADR-011 — do not build harness tooling):
  - Run five natural questions against the wiki via `/wiki-query` (examples: "which solutions use SQLite FTS5 and why", "what is the difference between GBrain's search and think modes", "what pattern do lint, dream cycle and dreaming pipeline share", "which tools chunk code at AST boundaries", "who built Hermes and what is its learning loop"). Each must be answered from pages with correct citations of page paths.
  - Run one question the wiki cannot answer ("what does the wiki know about Kubernetes operators") and confirm the explicit-gap behavior.
  - For two of the questions, record tokens and wall time for Path A (manual index read) vs Path B (wikiq) into `_reports/retrieval.csv` with columns `date,question,path,tokens,seconds,answered_correctly`. Two rows each is sufficient seeding; the trend analysis is future work.

**Validation gate:**
- [ ] `node scripts/wikiq.mjs "sqlite full text search"` ranks `sqlite-fts5` first.
- [ ] All 4.4 checks pass; `_reports/retrieval.csv` exists with ≥ 4 data rows.
- [ ] The novel-synthesis file-back path was exercised at least once (verify a `wiki(query):` commit exists).
- [ ] Commit: `wiki(retrieval): CLAUDE.md routing, wikiq scorer, query command, first retrieval log`

---

## 8. Phase 5 — Lint: micro formalized, deep built, observability seeded

**Goal:** the maintenance loop of ADR-008 exists end to end (manually triggered; scheduling is Phase 7).

5.1 Author `.claude/commands/wiki-lint.md` (C11) with two modes:
  - Default (micro): run the 3.2.7 checklist against pages changed since the last `wiki(` commit (`git diff --name-only`), plus the validator. Used standalone when needed; Ingest already embeds it.
  - `--deep`: delegate to the `wiki-deep-linter` subagent (5.2) and, on completion, run `scripts/append-health.mjs` (5.3).

5.2 Author `.claude/agents/wiki-deep-linter.md` (C14). Subagent definition: description "whole-wiki lint pass; report-first; auto-fix only whitelisted categories"; tools: file read/write, bash (for validator and git), NO network **[DECISION D3: deep lint never calls Deepen or fetches origins; it queues deepen tasks in the report]**. Its instructions:
  1. Read WIKI.md sections 8 and 10 first.
  2. Sweep the whole wiki for: orphan pages (inbound 0, excluding brand-new); contradictions between pages (claims about the same entity that cannot both hold); stale pages (`revalidate: true` or `revalidate_at` past — this list, priority-ordered by volatility, is the deepen queue); promotion candidates (sections > 50 lines or referenced from 3+ pages — use validator's link graph); index drift; alias collisions; relationship types outside D2.
  3. AUTO-FIX only: broken internal links, index drift, missing reciprocal links, frontmatter mechanical errors (the ADR-008 whitelist — hard boundary; everything else is report-only even if the fix seems obvious).
  4. Write `_reports/lint-YYYY-MM-DD.md` with sections: `## Auto-fixed` (itemized), `## Findings for human review` (itemized, each with the recommended action), `## Deepen queue`, `## Metrics snapshot`.
  5. Run validator; commit `wiki(lint): deep pass YYYY-MM-DD — n auto-fixes, m findings reported`.

5.3 Build `scripts/append-health.mjs` (C18): computes from `_index.yaml` + link graph and appends one row to `_reports/health.csv` with columns `date,pages_total,solutions,concepts,technologies,patterns,people,links_total,orphans,stale,avg_inbound,index_entries`.

5.4 Author `.claude/commands/wiki-status.md` (C13): prints last health row, last lint report summary, count of pending human-review findings, and the current deepen queue.

5.5 Install the Claude Code guard hook (C17) in `.claude/settings.json`: a `PostToolUse` hook matching Write/Edit on `solutions/|concepts/|technologies/|patterns/|people/|_index.yaml` that runs `node scripts/validate-index.mjs` and surfaces its output. (Soft, in-session guard; the pre-commit hook C16 remains the hard gate.)

5.6 Run `/wiki-lint --deep` once on the freshly ingested corpus. Expect a non-empty report — a ten-source ingest realistically leaves a few imperfect reciprocal links and possibly an orphan. Zero findings on first deep lint is suspicious: manually plant one defect (remove a reciprocal link), re-run, and confirm detection + auto-fix, before trusting an all-clear.

5.7 **Adversarial ingest (contradiction drill on real material).** The owner provides `ai-knowledge-concepts.md` — a six-concept comparative analysis NOT produced by solution-sumarizer, whose claims partially conflict with pages the corpus ingest created. Steps: (a) normalize it into `sources/ai-knowledge-concepts.md` with minimal frontmatter (title, `origin_urls` from its References section, `pipeline: external` recorded in the sources registry — Deepen must still work through its reference links); (b) run `/wiki-ingest` on it — expect updates concentrated on comparison-bearing pages (gbrain, qmd, codegraph, graphify, hermes-agent, the llm-wiki pattern page, and concept/pattern pages they share); (c) run `/wiki-lint --deep`. **Expected result: at least one `contradiction` finding**, e.g. this source's claim that GBrain is "the closest engineering realization" of Karpathy's pattern conflicts with the corpus-derived position that GBrain implements the consolidation cycle but not the synthesized-canon/query-write-back half; its "query-time write-back unimplemented by any tool" claim conflicts with the Hermes page's skills-as-use-time-write-back nuance. These MUST surface as report-only findings (never silently absorbed, never auto-resolved — ADR-008 whitelist). (d) **[HUMAN]** the owner adjudicates each finding (which claim wins, or both positions recorded); the agent applies the resolutions, and every adjudicated claim MUST carry inline attribution keys (`[^source-id]`, per the WIKI.md tiered attribution rule) so future lint passes can locate all claims touched by a given source. If step (c) yields zero contradiction findings, contradiction detection is broken: treat as a gate failure, fix the deep-linter instructions, re-run.

**Validation gate:**
- [ ] Deep lint produced a dated report with all four sections; whitelist boundary respected (verify the report's auto-fixed list contains only whitelisted categories).
- [ ] The planted-defect test passed.
- [ ] The adversarial ingest (5.7) produced ≥1 contradiction finding, reported not auto-fixed; owner adjudicated; resolutions applied and committed.
- [ ] `health.csv` has its first row; `/wiki-status` renders.
- [ ] C17 hook fires on a test edit.
- [ ] Commit: `wiki(maintenance): lint command, deep-linter agent, health metrics, status, guard hook`

---

## 9. Phase 6 — The Deepen operation

**Goal:** the escape hatch of ADR-003 works for at least one real page.

6.1 Author `.claude/commands/wiki-deepen.md` (C12), per SPEC §8.4. Instructions: argument = page id → resolve the page's `sources` frontmatter → resolve those distillates' `origin_urls` → fetch/process the origin using the appropriate approach for its type (web page: fetch; repo: clone/read; video: the claude-video watch pathway via solution-sumarizer's adapters — consult C20's SKILL.md **[HUMAN]** if the adapter invocation is unclear) → extract ONLY what the triggering need requires → update the page (and only pages justified by new material) → refresh `revalidate_at` from volatility, clear `revalidate` → write `origin_status: alive|dead|moved` + `last_verified: <date>` into the touched sources-registry entries (Deepen is a legitimate network context; this opportunistically enriches liveness data, ADR-016) → index + validator → commit `wiki(deepen): <page-id> — <reason>`.

6.2 Execute one real deepen run: take the top entry of the deepen queue from Phase 5's report (or, if empty, pick `solutions/qmd.md` and deepen against its GitHub origin). Verify the page gained specific detail absent from the distillate.

**Validation gate:**
- [ ] One deepen commit exists; the page diff shows origin-sourced detail; `revalidate_at` was refreshed.
- [ ] `sources/` distillates remain byte-identical (immutability held — `git status` clean under `sources/`).

---

## 10. Phase 7 — Automation

**Goal:** the weekly loop runs without a human at the keyboard (SPEC §9).

7.1 Build `scripts/check-origins.mjs` (C27) per the D11 status semantics: HEAD request per registry `origin_urls` entry (few-second timeout, one retry); `alive` on 2xx, `moved` on 3xx to a different host/path (record the target in the registry), `dead` ONLY on 404/410 or DNS failure confirmed on a repeat check in the same run, everything else (403, 429, robots-style refusal, timeout, network error) → `unverified`; write `origin_status` + `last_verified` into `_index.yaml`'s sources registry; exit 0 with a one-line-per-origin report. Zero npm dependencies (Node's built-in fetch).

7.2 Create `scripts/cron-deep-lint.sh`: `cd` into the repo, run `claude -p "/wiki-lint --deep" --dangerously-skip-permissions` is NOT acceptable — instead configure the minimal allowed-tools for headless lint (file edit, bash for validator/git) per Claude Code's headless permission flags; the deep-linter agent's no-network restriction (D3) must hold in headless mode. The wrapper runs `node scripts/check-origins.mjs` FIRST (deterministic HEAD checks, no LLM anywhere near the network — D11), commits any registry status changes, THEN launches the sandboxed lint session, so the lint report can consume fresh liveness data without the agent ever touching the network. Log stdout/stderr to `_reports/cron-YYYY-MM-DD.log`.

7.3 **[DECISION D5]** Install the cron entry (default Sundays 03:00): `0 3 * * 0 /path/to/llm-wiki/scripts/cron-deep-lint.sh`.

7.4 Dry-run: execute the script manually from a shell (not inside an interactive session) and confirm a lint report + commit + health row are produced end to end.

7.5 **[HUMAN]** Walk the owner through: reading a lint report, acting on `Findings for human review`, triggering `/wiki-deepen` from the deepen queue, and the agreement that the auto-fix whitelist widens only based on accumulated report history (ADR-008 consequence).

**Validation gate:**
- [ ] Dry-run produced report, commit, health row with no interactive prompts.
- [ ] Cron entry installed and next-run time confirmed.
- [ ] Commit: `wiki(automation): headless deep-lint script + schedule`

---

## 11. Phase 8 — Acceptance and handover

Final system test — all must pass:

- [ ] A1 End-to-end ingest: the human provides one NEW source (any type) → solution-sumarizer produces a distillate → `/wiki-ingest` integrates it → validator OK → the new solution is reachable via `/wiki-query` by a question about its domain.
- [ ] A2 The five-question set from 4.4 still answers correctly (no regression from lint/deepen activity).
- [ ] A3 `git log --oneline` reads as a coherent audit trail (every commit uses a `wiki(<op>):` prefix — ADR-007).
- [ ] A4 `/wiki-status` shows: 0 validator violations, deepen queue state, findings count.
- [ ] A5 Deliberate corruption drill: edit a page breaking a link and skipping the index → C17 flags it in-session → attempt commit → C16 blocks it → repair → clean.
- [ ] A6 All §1 inventory rows whose "Built in" phase is ≤ Phase 7 exist (C21–C25 belong to the post-handover Phases 9–10 and are exempt here); nothing outside the inventory was created.
- [ ] A7 Pending decisions D1–D7 are either resolved by the human or running on documented defaults; record the final state in a `## Decisions taken during implementation` section appended to this file.

Handover artifacts to the owner: this plan (with A7's appendix), the first deep-lint report, `health.csv`, and a short NEXT-STEPS note pointing at the SPEC §12 backlog (eval harness activation being the most likely next iteration).

---

## 12. Phase 9 — v0.5: Adoption enforcement & retrieval observability

**Goal:** wiki usage is gated by mechanism, not instruction; bloat and misses become measurable (ADR-013, ADR-014). This phase runs after the Phase 8 handover as the v0.5 iteration — it modifies a working system, so every step ends with the A2 regression check from Phase 8 (the five-question set must still answer correctly).

9.1 **[DECISION D8]** Build `scripts/inject-context.mjs` (C21): reads the prompt from the hook's stdin payload, runs the wikiq scoring routine (import the function from `wikiq.mjs` — refactor it to export `score(question, index)` if needed, keeping the CLI intact), and when the top score ≥ threshold, emits the injection block:
  ```
  [wiki-index] Possibly relevant wiki pages (open only what the answer needs, top-first):
  <score>  <id>  <path> — <summary>
  ```
  (top k = 3 entries, index data only — the script must never open page files). Below threshold: emit nothing, exit 0. Register it as a `UserPromptSubmit` hook in `.claude/settings.json`.

9.2 Build `scripts/log-access.mjs` + telemetry hook entries (C22): `PreToolUse`/`PostToolUse` matchers on Read/Grep/Glob whose file paths fall under the five page directories; append one JSON line per event to `_reports/access-trace.jsonl` with `ts, session, tool, path`. Telemetry must never block a tool call — log-and-continue only.

9.3 Amend `.claude/commands/wiki-query.md` (C10) with the ADR-014 contract: **[DECISION D9]** escalation budget (open the top scorer; each further open requires the previous page to have failed to answer; soft ceiling 5, justification recorded beyond it) and trace emission — append to `_reports/queries.jsonl` one record per query: `ts, question, candidates[], opened[], cited[], tokens, ceiling_justification?`. Also: every "wiki cannot answer" response appends a `no_answer: true` record.

9.4 Amend `.claude/agents/wiki-deep-linter.md` (C14) with the retrieval-behavior audit (SPEC §8.3 as amended): from `queries.jsonl` and `access-trace.jsonl`, produce findings for *missed-retrieval* (no-answer events where an existing page plainly covers the question — recommended action: enrich that page's index aliases/keywords/summary, NOT scorer changes), *low-utilization* (aggregate cited÷opened below 0.5 or declining across two reports), *grep-first violations*, and *ceiling-exceeded* queries. Extend `scripts/append-health.mjs` with `utilization_avg` and `miss_findings` columns. Index-metadata enrichments arising from miss findings are added to the deep-lint auto-fix whitelist ONLY as report-recommended edits applied on the next human-approved pass in v0.5; promotion of this category to autonomous auto-fix requires accumulated report history and explicit human approval (ADR-008 consequence).

9.5 **[HUMAN]** The owner authors `gold/questions.yaml` (C24): 10–15 real questions, each with `question`, `expected_pages: [ids]`, optional `expected_anchors`. The executing agent validates that every referenced id exists in `_index.yaml` and reports any question whose expected pages don't exist — each such case is either a taxonomy defect or an ingest gap, and must be resolved with the owner before the gate.

9.6 Amend `WIKI.md` (sections 8 and 10) and `CLAUDE.md` to document the new mechanisms; the routing note now describes injection as the primary mechanism with index-first as the fallback rule.

**Validation gate:**
- [ ] Injection fires: a wiki-relevant prompt ("how does gbrain's dream cycle work") produces the `[wiki-index]` block with `gbrain` ranked first; an irrelevant prompt ("write a haiku about rain") injects nothing. Both verified by observing the actual hook output.
- [ ] Telemetry: a test session opening two pages produces matching `access-trace.jsonl` lines; a deliberate `grep` across `concepts/` is captured.
- [ ] Trace + ratio: three `/wiki-query` runs produce three `queries.jsonl` records with non-empty `cited`; utilization computable.
- [ ] Planted-miss drill: temporarily strip a distinctive alias from one index entry, ask a question phrased with that alias, confirm the no-answer (or wrong-page) event is logged, run deep lint, confirm a missed-retrieval finding recommending the alias restoration, restore, re-ask, confirm recovery. (This exercises the full self-tuning loop end to end.)
- [ ] `gold/questions.yaml` exists, validates, and every expected page id resolves.
- [ ] A2 regression check passes.
- [ ] Commit: `wiki(observability): push-injection, telemetry, query traces, retrieval audits, gold set`

---

## 13. Phase 10 — v0.6: Governance dashboard

**Goal:** the wiki's state is auditable at a glance through a generated, read-only projection (ADR-015). Requires Phase 9 (the heat overlay consumes its traces); runs after the v0.5 gate.

10.1 **[DECISION D10]** Build `scripts/build-dashboard.mjs` (C25). It reads `_index.yaml`, the validator's link graph, `_reports/health.csv`, `_reports/queries.jsonl`, `_reports/access-trace.jsonl`, and the cron logs, and emits BOTH:
  - `_reports/dashboard-data.json` — the structured governance snapshot: nodes (id, type, inbound, volatility, stale flag, orphan flag, heat class), edges (typed relationships), sources (ingested/origin/`origin_status`+`last_verified`, `unverified` when no data), operations inventory, automations with last-run timestamps, headline metrics. This JSON is the wiki's published interface for the future ai-ideaverse workspace surface — treat its shape as a contract and document it in a comment header.
  - `_reports/dashboard.html` — a single self-contained file rendering four panels from that JSON: **Pages** (force graph: colored by type, sized by inbound, stale halos, orphans flagged), **Sources** (ingest registry with origin liveness: alive/dead/moved/`unverified`, from check-origins + Deepen data), **Operations** (commands/agent/scripts and what each touches), **Automations** (cron + hooks, last-run status). Heat overlay on Pages: cited-warm, opened-never-cited-cool, untouched-grey, from the trace data. No runtime network requests; vendored or hand-rolled rendering only.

10.2 Wire regeneration: deep lint (C14) calls the build script as its final step; add `--visual` to `/wiki-status` (C13) to rebuild on demand and print the file path.

10.3 The dashboard answers questions; verify it does. Sit with the rendered output and confirm each panel resolves its operational question from ADR-015: which pages are stale/orphaned (Pages), which origins are dead (Sources), what would a given operation touch (Operations), did the cron run last week (Automations), and which pages are alive vs. inert (heat). Any panel that cannot answer its question is incomplete — fix before the gate, and remove any element that answers nothing (the theater test).

**Validation gate:**
- [ ] Drift-immunity drill: delete both dashboard files, run `/wiki-status --visual`, confirm byte-equivalent regeneration (timestamps aside). The dashboard is disposable by construction.
- [ ] Read-only drill: confirm no script, command, or agent definition reads `dashboard.html`/`dashboard-data.json` as an input to any wiki operation (grep the repo for reads; the JSON is published FOR external consumers, never consumed internally as truth).
- [ ] Heat overlay reflects reality: pages cited in the Phase 9 test queries render warm; a page never touched renders grey.
- [ ] Staleness/orphan flags match the last deep-lint report exactly.
- [ ] Deep lint run regenerates the dashboard without manual intervention.
- [ ] Commit: `wiki(dashboard): governance projection — build script, four panels, heat overlay, status --visual`

---

## 14. Failure playbook (for the executing agent)

- Validator FAIL you cannot resolve → revert the working tree to the last commit (`git checkout -- .`), re-read WIKI.md, retry the operation at half the blast radius.
- Ingest wants to touch > 20 pages → stop, report the worksheet to the human (SPEC §8.1 bound).
- A distillate's frontmatter lacks `sources[].url` → ingest may proceed but the page's Deepen path is dead; record this in the sources registry as `origin_urls: []` and flag it in the ingest commit body.
- Conflict between this plan and SPEC/ADR → SPEC/ADR win; report the discrepancy.
- Anything requiring a capability you lack (e.g., video adapter unavailable) → do not fake the output; mark the step blocked and continue with independent steps.

---

## 15. References

External systems and sources named in this plan (Karpathy pattern, Jay E Second Brain, QMD, GBrain, CodeGraph, Graphify, Hermes, Milo, van der Hoeven, solution-sumarizer) are cited in full in `llm-wiki-spec.md` §15 and `llm-wiki-adr.md` References — both documents live in the repo root (plan step 1.5). The executing agent should treat those citation tables as the authoritative resolution of every short name used here, and must never cite a `sources/` distillate as if it were the primary source.
