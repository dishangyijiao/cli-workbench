# How a project is run

One owner, one builder agent at a time, one read-only reviewer agent, many small projects. This is the process every project under `~/dev/projects` follows.

It exists because work chosen by the last chat message drifts. In one project, 20 of 27 commits went to a convenience (a reading page and an upload button) while the core need, asking a book for advice with verified quotations, got no code, and direction changed four times in two days. Better engineering inside each task would not have fixed that. The cause is **selection**: nothing stood between an idea in chat and a builder writing code. This process puts a file there.

## The four operations

| # | Operation | What is written | You may not go on until |
| - | --------- | --------------- | ----------------------- |
| 1 | **Choose** | One row in the project's ledger becomes `Now`, with the owner's reason and what it displaces | The owner chose it (recorded in the ledger), and it names the core outcome it serves or records the owner's deliberate exception |
| 2 | **Prepare** | An item record (`docs/items/I-NNN-name.md`, from `templates/workflow/item.md`): the effect the owner will see (Given, When, Then), the demo steps, the budget, what is out, blocking questions | The item is **Ready** (below) |
| 3 | **Build and verify** | Code on one branch for the item, with tests; the project's technical check | The check passes on the revision the owner will demo, and the output is in the pull request |
| 4 | **Accept and deliver** | The owner runs the demo steps and records `accepted`, `changes` or `rejected`, what they saw, the date and the revision | The owner's record names the revision that is merged. Delivery (merged, installed, released) is recorded separately |

Existing project documents stay where they are and are updated when their facts change: `docs/PRD.md`, `docs/SPEC.md`, `docs/THREAT-MODEL.md`, `docs/adr/`. They are not stages every item must pass through.

## States

An item is in exactly one state: `Inbox` → `Ready` → `Building` → `Verified` → `Accepted`, with `Parked` and `Dropped` as exits. Delivery is a second, separate field: `unreleased`, `installed <revision>` or `released <version>`.

- Only the owner moves an item to `Ready` as the bet, to `Accepted`, or to `Dropped`.
- The builder says `Verified` (the checks passed), never `Done`. **Done means Accepted.**
- Changing the code or the acceptance text after Verified or Accepted voids that state until it is redone.
- When idle, zero items may be `Building`. Two is never allowed.

## The rules that carry the weight

**An idea is not a bet.** Anything the owner or the agent thinks of goes to the Inbox in one line. A request in chat is an idea until the owner's choice is recorded under Choose. The builder starts nothing that is not `Now`. A request that falls outside the active item's written effect is a **scope change**, even on the same branch: it goes to the Inbox, or the item is revised and re-chosen.

**Every bet has a price.** Choosing an item says what it displaces: "This delays the consultation slice because …; we revisit after …". A bet that is not the next core slice names the core outcome it makes possible, or records the owner's deliberate exception and the condition for revisiting it. A fully compliant owner can still choose convenience every time; this rule makes that a visible decision, not a drift.

**One thing at a time.** One item `Building`. A second starts only when the first is Accepted, or Parked with the reason and the code left on its branch. A direction change while an item is in progress is a stop: the change is recorded (ledger edit or ADR), the displaced work and its cost are named, the owner re-chooses, and only then does building continue.

**Show the core before building more around it.** Before choosing infrastructure for a core job, run the core job once with what exists and record the real blocker. Then build what removes that blocker.

**Tracer bullet first, for uncertain or large items.** The first slice goes through every layer the owner will see, ugly but real, and is demoed before the rest is built; the owner's answer (`continue`, `change`, `stop`) is written in the item. Small or well-understood items skip this.

**Decide in a file, when it is consequential.** An ADR is written when a choice (a) changes a boundary, an input or what is trusted, (b) picks or drops a dependency, format or protocol that is costly to reverse, (c) reverses an earlier ADR, or (d) the owner and the builder disagreed on something that matters. A routine implementation detail inside the approved item is the builder's call. The owner accepts an ADR; the builder drafts it. A decision with lasting cost goes to the reviewer first, and each finding gets a written response (accepted, or rejected with the reason). Accepted ADR bodies are not edited; status and links may be.

**Evidence, not assertion.** A claim (verified, safe, unused, faster) comes with a test, a log or a command's output, for a named revision. What was not run is listed, and a required check that was not run means the item is not Verified.

## Definitions

**Ready** (to leave Prepare): the effect is written as Given, When, Then in the owner's words; the demo steps are written; the budget is a number of hours or days; the ledger row and the core outcome or exception are named; no **blocking** question is open (a blocking question is one whose answer changes what is built; the rest are listed and may stay open).

**Verified** (to leave Build): the project's technical check passes; every behaviour change has a test that failed before the change; the spec, threat model, READMEs and changelog are updated if behaviour the owner sees changed; the pull request lists the required checks that ran and the ones that did not.

**Accepted** (to leave Demo): the owner ran the demo steps on a named revision and wrote `accepted`, what they saw, and the date. `changes` returns the item to `Building` inside the same scope. `rejected` records why and parks or drops it.

## Who does what

| Role | Does | Does not |
| ---- | ---- | -------- |
| **Owner** | Writes the north star, chooses the bet, runs the demo, accepts, merges, drops or promotes ideas | Is not asked to decide what has an obvious default |
| **Builder** (the one writer) | Prepares items for the owner's choice, drafts ADRs, builds, verifies, writes demo steps, keeps the ledger honest | Starts an item that is not `Now`, says `Done` or `Accepted`, merges, edits an accepted ADR body, changes the checks that gate it in the same pull request without saying so |
| **Reviewer** (a second model) | Reads the original requirement and the real diff, reports findings; read-only | Writes to the working copy |

One agent writes to a working copy at a time. Local Git authorship cannot prove the owner wrote an acceptance when the builder uses the same account; for one owner this is accepted, and merge authority stays with the owner (the builder opens the pull request and stops).

## Paths that are not a feature

| Situation | Minimum path |
| --------- | ------------ |
| **Tiny change with no behaviour** (typo, comment, formatting) | Say so in the commit; run the relevant checks; the owner merges. No item, ADR or demo |
| **Bug fix** | Record the reproduction; a test that fails first; normal checks. It rides the active item only if it is inside its written effect, otherwise it is its own item (urgent ones may go first, see below) |
| **Urgent failure or security issue** | Stop harmful use; keep evidence and data; contain or revert; record the interruption in the ledger; accept afterwards in a shortened demo |
| **Research spike** | Item with a question, a fixed budget, the experiment and the decision it informs. It ends with evidence and a recommendation. Spike code is not shippable until it is its own item |
| **Budget runs out** | Stop and show the evidence; the owner reduces scope, parks, or extends in writing. Acceptance is never silently dropped |
| **Builder and reviewer disagree** | Record the finding, the response and who decided (the owner for product and compatibility, the builder inside the approved item) |
| **Owner unavailable** | Finish preparation and verification; leave the item `Verified`, not `Accepted` |
| **Release or install** | Record the revision or version, the install step, a smoke result, compatibility changes and the way back. The project's version policy (for example in its CHANGELOG) applies |
| **Adopting the process in a project** | List the existing documents and work; settle contradictions; choose one `Now` item; install the checks; show that an item that is not Ready is refused. Existing releases get no invented acceptance records: mark them `legacy` |
| **Changing the process** | The owner approves a concrete change in this repository; the templates and checks change in the same pull request; each project migrates on purpose |

## What is enforced and what is only written

A document that asks the builder to behave does not change what the builder does. These are the controls that make the boundary real. Status of each is stated here so nobody believes a rule is enforced when it is not.

| Control | What it does | Status |
| ------- | ------------ | ------ |
| **Readiness check** (`scripts/workflow-check`) | Reads the ledger and the item record; fails unless exactly one item is `Building` (or none while idle), it is `Ready`, the owner's choice is recorded, and the effect, budget and demo steps exist. Called before implementation by the session start hook and by CI | Not built |
| **Pull request check** | Runs the same check on the branch's item, plus: the item named in the branch exists, the verification output names this revision, and a change to the check itself or to an accepted ADR body is flagged for the owner | Not built |
| **Acceptance action** | One command the owner runs that appends `accepted`/`changes`/`rejected`, the observation, the date and the revision to the item; stale if the code or the criteria changed since | Not built |
| Builder cannot merge | Merge stays with the owner; branch protection plus the builder's permissions | Written in project `AGENTS.md`; not verified on the remote |
| Tests exist for a change | `scripts/tdd-gate` in this repository: a feat/fix/refactor/perf commit that changes product code adds or changes a test file | Built (workbench only) |
| Ledger HTML is current | `scripts/ledger-html.py --check` in CI | Built (inkspring) |

The first proof the process works is one item refused by the readiness check, and one accepted consultation of the core job.

Checks do not decide whether the right thing was chosen. That is the owner's judgment at Choose, and the reviewer's job is to challenge the stated reason.

## Test-first policy

The shared default is: a behaviour change comes with a test that failed before the change, and the commit that makes it pass contains or follows that test. Whether the red test is its own commit is a project choice. inkspring requires a separate red commit; the workbench's `tdd-gate` instead requires a test in the commit. Where the two meet, the project's rule wins and the gate's `tdd: skip - <reason>` line names the earlier red commit. A red ancestor does not prove the test came first; it is a trace for the reviewer, not a proof.

## Direction check

At each Choose, not only in a periodic review, answer from the repository:

1. **What new part of the core job can the owner do now, since the last review?** Link the accepted demo.
2. **What displaced it?** List each non-core item, interruption and parked item with its rough budget.
3. Inbox ideas older than two weeks: promote, park or drop.
4. One thing in this process that cost more than it gave: change it.

A commit count by category is a diagnosis tool, not a control: it is easy to game by splitting commits or by labelling work. If used, save the commit range and the classification rules with the result.

## Where each fact lives

One fact, one place (each project's `docs/SOURCE-OF-TRUTH.md`). This file is the process; project files are the facts.

| Fact | File |
| ---- | ---- |
| Why the project exists, who for, north star, a concrete success example | `docs/PRD.md` |
| What is wanted, its order, which item is `Now`, and each item's state | `docs/FEATURE-LEDGER.md` (authoritative for scheduling; implementation facts link to the changelog and tests) |
| What one item will look like, its demo and the owner's acceptance | `docs/items/` |
| Why a consequential choice was made | `docs/adr/` |
| What must hold | `docs/SPEC.md` |
| What can go wrong and what stops it | `docs/THREAT-MODEL.md` |
| Shared visual choices of a screen | One hand-written stylesheet of CSS variables (below) |
| Recovery: the way back from a bad install or damaged data | `docs/SOURCE-OF-TRUTH.md` or a short section in the README |

Project `AGENTS.md` links to the north star and the ledger and does not copy them (a copy goes stale). Its read order starts with the ledger and the active item, then the scoped context.

## Shared visual choices

A project with a screen keeps the colours, type roles, spacing and control styling that more than one place uses in **one hand-written stylesheet of semantic CSS variables** (`design/theme.css`), light and dark values included, and includes it in each page (in a Rust project with `include_str!`). View-specific layout stays local. Deliberate differences (serif reading text, sans-serif controls) are named roles. Zero margins, layout ratios and media-query thresholds are not variables.

A test checks that every page includes it and that shared declarations are not repeated. If a second consumer of the values appears (another tool, a design program), move to the [Design Tokens Community Group](https://www.designtokens.org/tr/2025.10/format/) JSON format (a Community Group report for interchange, not a W3C standard) with a generator that has a `--check` mode run in CI. Not before.

Screens are judged by four rules: contrast, repetition, alignment, proximity. Screenshots are asked for only the states a change affects.

## Templates

Shared templates live in `templates/workflow/` in this repository: one **item** template (effect, demo steps, budget, out of scope, blocking questions, the owner's acceptance block, the displaced work), one **ADR** template (for the consequential cases), and one **pull request** template (item, scope changes, review findings and responses, verification output with the revision, what was not run, acceptance reference). They are copied into a project when it adopts the process, as starting documents, not generated policy. A template must not widen what a project's own rules forbid, such as "do not merge on your own".

## Where this came from

Backlog ordering is [MoSCoW](https://en.wikipedia.org/wiki/MoSCoW_method). Budget and betting are from [Shape Up](https://basecamp.com/shapeup/4.5-appendix-06): fixed time, variable scope. Acceptance as Given, When, Then is Dan North's, from [behaviour-driven development](https://en.wikipedia.org/wiki/Given-When-Then). Decision records follow Michael Nygard's format. The one-item limit is Kanban's. Tracer bullets and the walking skeleton are from The Pragmatic Programmer and Alistair Cockburn. An independent review of the first draft (2026-10-07) cut the twelve stages to four, added the displacement rule, the state model and the enforcement table, and replaced a JSON token pipeline with one stylesheet.
