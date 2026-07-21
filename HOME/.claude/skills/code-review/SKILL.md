---
name: code-review
description: Adversarial multi-agent review for implementation changes. Reviews correctness, performance, API usability, test coverage (including equivalence classes and negative cases), and spec/doc synchronization in parallel; tries to refute top claims before reporting them. Repeats until no validated findings remain, then runs benchmarks.
---

# Code Review

Adversarially review completed implementation changes before external review. Treat every finding as a claim to test, not a conclusion.

## When to Use

- After completing any implementation, modification, or bug fix
- When explicitly asked to "review" the implementation

## Definitions

- **Security-sensitive code**: enforces access control, validates credentials, handles secrets, prevents injection, or makes trust decisions. When in doubt, treat it as sensitive; false caution is cheap.
- **Hot path**: executes per-item, per-request, or in a tight loop rather than once during setup/teardown.
- **Full test suite**: all CI tests (unit + integration). If fast/slow suites are separate, run at least fast tests during iteration and all tests before sign-off.
- **Claim**: a specific actionable defect with source evidence, an affected input/path, and user-visible or operational impact.

## Review Loop

Repeat until a round produces no validated findings.

### 1. Investigate in Parallel

Run at least two independent reviewer agents concurrently (in waves if needed). Give them the diff and only necessary code, tests, and specs; cover all five lenses below, combining lenses when slots are limited, without revealing others' conclusions.

Apply relevant language/runtime skills during investigation. For C#/.NET, also use `$dotnet-best-practices`; additionally use `$dotnet-micro-optimization` only for performance-sensitive changes or a known hot function.

#### Correctness

- Verify that the logic matches the stated intent. Trace each branch with concrete inputs.
- For **classification/decision logic**, enumerate variable combinations and check for:
  - Conditions that are **true but should be false** (false positives) — most commonly missed
  - Conditions that are **false but should be true** (false negatives)
- For **security-sensitive code**, confirm negative test count >= positive test count.
- Verify that error messages and diagnostics are accurate and helpful.

#### Performance

Check against the project's performance constraints:

- Identify unnecessary allocations in hot paths (loops, per-request code, per-item processing).
- Identify expensive operations (regex compilations, repeated lookups, growable collections) in code that runs per-item.
- Consider whether stack-based or pooled alternatives can replace heap allocations.
- Verify that algorithmic complexity fits the expected input size.

#### API Usability

Evaluate from the caller's perspective:

- Verify that the API is **straightforward** and does what users intuitively expect.
- Require method names to be self-explanatory without reading implementation.
- Identify behavior that would surprise users. **Prefer fixing the behavior**; document only when fixing would break backward compatibility or introduce unacceptable complexity.
- Eliminate unnecessary ceremony (extra parameters, wrapper types, configuration).
- Verify idiomatic resource management for the language (e.g., `using` in C#, `defer` in Go, context managers in Python).

#### Test Coverage

- Verify tests for each equivalence class of classification logic.
- Require at least one test for each branch of multi-variable conditions.
- For bug fixes, require a regression test that would catch re-introduction.
- For security-sensitive code, require negative tests (should NOT flag) >= positive tests (should flag).
- Use realistic caller patterns rather than internal implementation details.

#### Spec/Doc Synchronization

- If behavior changed, confirm that relevant design docs or API specs are updated.
- If user-facing docs (README, usage guides, API references) describe the behavior, verify that they remain accurate.
- Cross-check that docs, code, and tests all agree on the same behavior.

Reviewers return only claims with exact evidence, impact, and confidence; never inflate uncertainty into a finding.

### 2. Rank and Deduplicate

Merge duplicates; rank by impact severity, then likelihood/reproducibility, affected scope, and confidence. Exclude only style preferences and unsupported suspicions. Every remaining report-worthy claim enters the ranked shortlist and must pass Step 3, highest first.

### 3. Try to Refute Every Top Claim

For each shortlisted claim, start **three independent verification agents in parallel**. Give them the claim and relevant raw artifacts, never other verifiers' reasoning or votes. Instruct each:

> **Be SKEPTICAL. Try to REFUTE this claim.**

Inspect the implementation, tests, and contract; trace or reproduce the failure; run focused safe checks. Vote **REFUTED** only with concrete counterevidence (e.g. unreachable path, permitted behavior, failed valid reproduction). Otherwise vote **NOT REFUTED**: missing evidence, uncertainty, and disagreement are not refutation.

- After all three valid votes arrive, remove a claim when at least 2/3 vote **REFUTED**; otherwise keep it with its strongest evidence and calibrated severity.
- Never simulate or infer votes. If three verifiers are unavailable, stop with verification incomplete; do not fix, report, or validate that claim.
- Exclude removed claims from the report; only a filtered-claim count may remain.

### 4. Apply Validated Fixes

For each surviving finding:

1. Demonstrate it with a failing test (red), or a focused reproduction, benchmark, or doc/spec assertion when an automated regression test does not apply.
2. Apply the minimum fix.
3. Confirm the check passes (green).
4. Run the full test suite.
5. Restart from parallel investigation.

## Completion

After a round has no surviving findings:

1. Run the full test suite.
2. Run relevant benchmarks against the project's regression threshold, or **+10%** for latency and memory if undefined. For performance-sensitive changes without benchmarks, recommend one but do not require it to pass.
3. Update docs/specs for any behavior changed by review fixes.

## Checklist Summary

- [ ] Independent agents covered correctness, performance, API, tests, and docs/specs concurrently; evidenced claims are deduplicated and ranked
- [ ] Every report-worthy claim got three independent votes; 2/3-refuted claims were removed
- [ ] Classification combinations and false positives are tested; security-sensitive code has negative tests >= positive tests
- [ ] Hot paths avoid needless work; APIs are straightforward and tested through idiomatic caller patterns
- [ ] Docs/specs, implementation, and tests agree; the full suite and applicable benchmarks pass
