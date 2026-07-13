# Plan 058: Build a global agent-efficiency evaluator with model-attributed cost

> **Executor instructions**: This plan changes personal Codex tooling under
> `/Users/usuario/.codex`, not Prisma product source. Execute it in a dedicated
> global-configuration task with explicit operator authorization. Do not let a
> Prisma implementation agent write outside its isolated worktree. If the
> current execution policy cannot provide an approved isolated/staged workflow
> for global files, stop and request that workflow instead of bypassing policy.
>
> **Global drift check (run first)**:
> `shasum -a 256 /Users/usuario/.codex/bin/codex-usage-report.py /Users/usuario/.codex/evals/README.md /Users/usuario/.codex/evals/tasks.jsonl`
> Expected planned hashes are listed under "Current state". If they differ,
> reconcile the live files before proceeding.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none
- **Category**: dx / tests
- **Planned at**: Prisma commit `58ca8a84`, 2026-07-12; global files are not currently in a Git worktree

## Why this matters

The current study measures tokens and time, but scenario/profile labels are
supplied by the caller and every recorded session reports the same model and
effort. It cannot prove which child model/role produced the usage, compare
quality consistently, count rework, or translate cached/uncached/reasoning
tokens into cost. A narrow global `agent-efficiency-eval` skill should make
controlled comparisons reproducible across projects while continuing to avoid
prompt, response, tool-argument, transcript, and secret content.

## Current state

- `/Users/usuario/.codex/evals/tasks.jsonl` defines six stable task classes:
  search, explain-flow, bug-diagnosis, small-change, diff-review, and
  implementation-plan, with one acceptance sentence each.
- `/Users/usuario/.codex/evals/README.md:21-28` requires the same manifest,
  prompt, revision, disposable worktree, three repetitions, and separate quality
  acceptance.
- `/Users/usuario/.codex/bin/codex-usage-report.py:38-119` reads session metadata,
  timestamps, model/effort, turns, tool-call count, and cumulative usage without
  reading prompt/tool content.
- `/Users/usuario/.codex/bin/codex-usage-report.py:128-133` accepts `--profile`
  and `--status`, then applies those caller-supplied labels to every selected
  session; task ID, role, acceptance, and rework are absent.
- All three controlled reports contain 18 completed `gpt-5.6-luna` / `medium`
  session records, so the report cannot independently verify the treatment named
  "mixed" or attribute child usage.
- Planned global hashes:

```text
aa6d9aa93e612b0933f51a10c23756273658b67ae798928f739712c56a9bc567  /Users/usuario/.codex/bin/codex-usage-report.py
8675cce1b4e62f685a00c27ad5c88190426d30de993888b856f8ceac3d9001b3  /Users/usuario/.codex/evals/README.md
ccdf70ce9eb6a458723ae94bff0fbd544132222ef84fdf2b62da635013486f6e  /Users/usuario/.codex/evals/tasks.jsonl
```

### Official OpenAI pricing snapshot collected 2026-07-12

USD per one million tokens, Standard tier, short context. Source:
https://developers.openai.com/api/docs/pricing

| Model | Input | Cached input | Cache write | Output |
|---|---:|---:|---:|---:|
| `gpt-5.4-nano` | $0.20 | $0.02 | — | $1.25 |
| `gpt-5.4-mini` | $0.75 | $0.075 | — | $4.50 |
| `gpt-5.4` | $2.50 | $0.25 | — | $15.00 |
| `gpt-5.4-pro` | $30.00 | — | — | $180.00 |
| `gpt-5.5` | $5.00 | $0.50 | — | $30.00 |
| `gpt-5.5-pro` | $30.00 | — | — | $180.00 |
| `gpt-5.6-luna` | $1.00 | $0.10 | $1.25 | $6.00 |
| `gpt-5.6-terra` | $2.50 | $0.25 | $3.125 | $15.00 |
| `gpt-5.6-sol` / alias `gpt-5.6` | $5.00 | $0.50 | $6.25 | $30.00 |

Batch and Flex use the same published rows and are generally 50% of Standard:

| Model | Input | Cached | Cache write | Output |
|---|---:|---:|---:|---:|
| 5.4 nano | $0.10 | $0.01 | — | $0.625 |
| 5.4 mini | $0.375 | $0.0375 | — | $2.25 |
| 5.4 | $1.25 | $0.13 | — | $7.50 |
| 5.4 Pro | $15.00 | — | — | $90.00 |
| 5.5 | $2.50 | $0.25 | — | $15.00 |
| 5.5 Pro | $15.00 | — | — | $90.00 |
| 5.6 Luna | $0.50 | $0.05 | $0.625 | $3.00 |
| 5.6 Terra | $1.25 | $0.125 | $1.5625 | $7.50 |
| 5.6 Sol | $2.50 | $0.25 | $3.125 | $15.00 |

Published Priority rows:

| Model | Input | Cached | Cache write | Output |
|---|---:|---:|---:|---:|
| 5.4 mini | $1.50 | $0.15 | — | $9.00 |
| 5.4 | $5.00 | $0.50 | — | $30.00 |
| 5.5 | $12.50 | $1.25 | — | $75.00 |
| 5.6 Luna | $2.00 | $0.20 | $2.50 | $12.00 |
| 5.6 Terra | $5.00 | $0.50 | $6.25 | $30.00 |
| 5.6 Sol | $10.00 | $1.00 | $12.50 | $60.00 |

Priority has no row in the cited table for 5.4 nano, 5.4 Pro, or 5.5 Pro;
store those as unavailable, not zero. The official table labels 5.4/5.5/Pro
prices as `<272K context length`; the evaluator must not silently apply them to
long-context runs without a verified current rule. Eligible regional endpoints
released on or after 2026-03-05 have a published 10% uplift.

Reasoning documentation:
https://developers.openai.com/api/docs/guides/reasoning

- Effort does not change the per-token tariff. It changes the number of generated
  reasoning tokens and latency.
- Reasoning tokens are billed as output and are already included in
  `usage.output_tokens`; never add `reasoning_tokens` a second time.
- 5.6 supports `none`, `low`, `medium`, `high`, `xhigh`, and `max`; 5.4/5.5
  variants support model-specific subsets.
- 5.6 pro mode uses more model work but bills aggregated tokens at the selected
  model's standard token rates.

The current study's API-equivalent Luna/Standard cost, if every recorded session
were truly billed as Luna, is approximately $1.2444 single, $1.2571 mixed, and
$1.0971 homogeneous. That means +1.0% and -11.8% relative to control, not +9.5%
and -5.1%, because cached tokens are discounted. These are calibration values,
not proof of actual Codex billing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Skill validation | `python3 /Users/usuario/.codex/skills/agent-efficiency-eval/scripts/test_evaluator.py` | exit 0; synthetic fixtures pass |
| Compatibility CLI | `python3 /Users/usuario/.codex/bin/codex-usage-report.py --help` | exit 0; old entrypoint still works |
| Privacy scan | `rg -n "prompt|response_text|tool_arguments|tool_output|transcript|secret" /Users/usuario/.codex/skills/agent-efficiency-eval /Users/usuario/.codex/evals/README.md` | only explicit prohibition/schema-test references |
| Controlled report | run the skill on a synthetic run manifest | cost, latency, acceptance and attribution fields are present |
| Config health | `codex doctor --summary` | config/state healthy; unrelated environment warnings classified |

## Suggested executor toolkit

- Use `skill-creator` to scaffold and validate the global skill.
- Use `openai-docs` to refresh the pricing snapshot only from official OpenAI
  pages before implementation.
- Use `agent-ops` to keep evaluation separate from normal routing decisions.

## Scope

**In scope**:

- `/Users/usuario/.codex/skills/agent-efficiency-eval/` (create)
- `/Users/usuario/.codex/bin/codex-usage-report.py` (compatibility wrapper or narrow extension)
- `/Users/usuario/.codex/evals/README.md`
- `/Users/usuario/.codex/evals/tasks.jsonl`
- `/Users/usuario/.codex/evals/runs/` schema and ignored/local artifacts
- Synthetic tests/fixtures inside the new skill
- `plans/README.md` status only, maintained from the Prisma planning task

**Out of scope**:

- Reading or persisting prompts, responses, tool arguments/outputs, transcripts,
  source contents, API keys, authentication files, or secrets.
- Claiming public API-equivalent cost is the user's actual ChatGPT/Codex charge.
- Automatically changing models, reasoning effort, plugins, agents, or profiles.
- Scraping unofficial pricing or treating a missing price as zero.

## Execution workflow

- Use one dedicated global-configuration task and one writer.
- Before edits, copy the in-scope global files into an operator-approved backup
  location and record hashes; never include `auth.json` or secrets.
- If the operator provides a version-controlled personal tooling repository,
  stage the skill there and install it through the supported skill/plugin flow.
  Otherwise keep changes narrowly scoped and retain rollback copies.
- Do not modify Prisma source while executing this global plan.

## Steps

### Step 1: Create the narrow evaluation skill

Create `/Users/usuario/.codex/skills/agent-efficiency-eval/SKILL.md` with a
specific trigger: controlled comparison of agent profiles/models/efforts and
cost reporting. It must not own day-to-day routing; `agent-ops` remains the
workflow owner.

Move reusable report logic into the skill's `scripts/` and leave
`~/.codex/bin/codex-usage-report.py` as a compatibility wrapper if practical.
Avoid two independent implementations.

**Verify**: invoking the old CLI and the skill script on the same synthetic
fixture produces the same token totals.

### Step 2: Add explicit run and acceptance manifests

Define privacy-safe schemas:

- run ID and task ID;
- scenario/profile selected;
- root and child role;
- actual model/effort from session metadata when available;
- repository revision and disposable worktree identifier;
- start/end/session IDs;
- acceptance pass/fail plus criterion ID;
- rework count and completion status.

The controlled runner, not a time-window guess, must map session IDs to task and
scenario. When child attribution is unavailable, report `unknown` and omit cost
for that segment instead of assigning the root model.

**Verify**: a fixture with an unknown child model produces a partial-attribution
warning and never invents a price.

### Step 3: Add versioned pricing and correct cost accounting

Create a machine-readable pricing snapshot containing model ID, service tier,
context band, input/cached/cache-write/output rates, currency, unit,
`effective_date`/collection date, and official source URL. Populate the official
2026-07-12 values above, then refresh them from the official page immediately
before committing.

Use this formula per attributed model segment:

```text
uncached_input = input_tokens - cached_input_tokens

token_cost = (
  uncached_input       * input_rate
  + cached_input       * cached_rate
  + cache_write_tokens * cache_write_rate
  + output_tokens      * output_rate
) / 1_000_000

total_cost = token_cost + tool_costs + container_costs + regional_uplift
```

Do not add reasoning tokens separately. When cache-write telemetry, service tier,
context band, or tool costs are unknown, expose the limitation and calculate
only a labeled partial/API-equivalent estimate.

**Verify**: synthetic hand-calculated fixtures cover Luna, Terra, Sol, 5.4,
5.5, cached input, unavailable prices, and reasoning-token non-duplication.

### Step 4: Report quality and resource metrics together

Emit per-task, per-role, per-model, and scenario aggregates including:

- total, input, cached, uncached, output, and reasoning-output tokens;
- API-equivalent cost and attribution coverage;
- wall-clock makespan and summed agent duration;
- acceptance rate, incomplete rate, rework count;
- cache ratio and scenario delta against control;
- median and spread across at least three repetitions.

Never rank a cheaper scenario above control when acceptance regresses or rework
erases the saving.

**Verify**: a cheaper-but-failing synthetic scenario is labeled rejected.

### Step 5: Re-run the six-task study

Run each scenario three times with the same prompt, revision, worktree fixture,
and acceptance evaluator. Preserve the current single, homogeneous, and mixed
scenarios, but require actual role/model attribution.

Publish only privacy-safe aggregate reports under `~/.codex/evals/reports` and
record whether costs are API-equivalent or actual billed values.

**Verify**: every scenario has the same task/repetition counts, 100% model/role
attribution or an explicit incomplete flag, and an acceptance verdict.

## Test plan

- Synthetic JSONL only; tests must not read the user's real prompts or outputs.
- Cost golden cases for every published family/tier needed by the study.
- Missing/unknown model, missing cache-write, missing acceptance, corrupt event,
  and duplicated session-ID cases.
- Reasoning tokens included in output exactly once.
- Same-task three-run aggregation and wall-clock vs summed-duration calculations.

## Done criteria

- [ ] A narrow global `agent-efficiency-eval` skill exists and does not overlap `agent-ops`.
- [ ] Old usage-report entrypoint remains compatible or has a documented migration.
- [ ] Scenario/task/role/model attribution comes from a run manifest plus session metadata.
- [ ] Acceptance and rework are first-class metrics.
- [ ] Pricing is versioned, official-source-only, tier/context aware, and refreshable.
- [ ] Reasoning tokens are not double counted.
- [ ] Unknown attribution/pricing produces an honest partial result.
- [ ] Synthetic tests pass without reading sensitive session content.
- [ ] The six-task study is rerun with three repetitions and quality acceptance.
- [ ] `plans/README.md` marks plan 058 `DONE`.

## STOP conditions

- Implementation requires reading prompt, response, tool argument/output, source
  content, transcript, authentication, or secret data.
- Child model/role attribution cannot be established and the proposed fallback
  is to assume the root model.
- Official pricing cannot be refreshed or a required tier/context price is absent.
- Global writes cannot be performed under an operator-approved isolated/staged workflow.
- A cost is presented as actual Codex billing without billing evidence.

## Maintenance notes

Pricing snapshots are data with provenance, not permanent constants. Refresh
before major comparisons, retain historical snapshots for reproducibility, and
display collection date/source in every report.
