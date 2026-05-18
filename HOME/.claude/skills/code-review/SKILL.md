---
name: code-review
description: Iterative self-review workflow for implementation changes. Covers correctness, performance, API usability, test coverage (including equivalence-class and negative-case completeness), and spec/doc synchronization. Repeats review rounds until no findings remain, then runs benchmarks.
---

# Code Review

Iterative self-review of implementation changes. Run this after completing an implementation task to catch issues before they reach external reviewers.

## When to Use

- After completing any implementation, modification, or bug fix
- When explicitly asked to "review" the implementation

## Definitions

- **Security-sensitive code**: code that enforces access control, validates credentials, handles secrets, sanitizes inputs for injection prevention, or makes trust decisions. When in doubt, treat as security-sensitive (false caution is cheap).
- **Hot path**: code that executes per-item, per-request, or in a tight loop. Contrast with setup/teardown code that runs once.
- **Full test suite**: all automated tests the project runs in CI (unit + integration). If the project separates fast/slow suites, run at minimum the fast suite; run the full suite before final sign-off.

## Review Loop

Repeat until a round produces zero findings:

### 1. Correctness Review

- Does the logic match the stated intent? Trace each branch with concrete inputs.
- For **classification/decision logic**: enumerate variable combinations and check for:
  - Conditions that are **true but should be false** (false positives) — most commonly missed
  - Conditions that are **false but should be true** (false negatives)
- For **security-sensitive code** (see Definitions): confirm negative test count >= positive test count.
- Are error messages and diagnostics accurate and helpful?

### 2. Performance Review

Check against the project's performance constraints:

- Are there unnecessary allocations in hot paths (loops, per-request code, per-item processing)?
- Are there expensive operations (regex compilations, repeated lookups, growable collections) in code that runs per-item?
- Could stack-based or pooled alternatives replace heap allocations?
- Is the algorithmic complexity appropriate for the expected input size?

### 3. API Usability Review

Evaluate from the caller's perspective:

- Is the API **straightforward**? Does it do what a user would intuitively expect?
- Are method names self-explanatory without reading implementation?
- Would a user be surprised by any behavior? If yes, **prefer fixing the behavior**; document only when fixing would break backward compatibility or introduce unacceptable complexity.
- Is there unnecessary ceremony (extra parameters, wrapper types, configuration) that could be eliminated?
- Does resource management follow idiomatic patterns for the language? (e.g., `using` in C#, `defer` in Go, context managers in Python)

### 4. Test Coverage Review

- Are there tests for each equivalence class of classification logic?
- Is there at least one test for each branch of multi-variable conditions?
- For bug fixes: does a regression test exist that would catch re-introduction?
- For security-sensitive code: do negative tests (should NOT flag) outnumber or equal positive tests (should flag)?
- Do tests use realistic caller patterns, not internal implementation details?

### 5. Spec/Doc Synchronization

- If behavior changed: are relevant design docs or API specs updated?
- If user-facing docs (README, usage guides, API references) describe this behavior: are they still accurate?
- Cross-check: do the docs, the code, and the tests all agree on the same behavior?

## Applying Fixes

When a finding is identified:

1. Write a failing test that demonstrates the issue (red)
2. Apply the minimum fix
3. Confirm the test passes (green)
4. Run the full test suite (see Definitions)
5. Continue the review loop from the top

## Completion

After a clean review round (zero findings):

1. Run the full test suite
2. If benchmarks exist for the changed area, run them and verify against the project's regression threshold. Default threshold (when project does not define one): **+10%** for both latency and memory. If no benchmarks exist and the change is performance-sensitive, adding a benchmark is recommended but not required for the review to pass.
3. Update docs/specs if any behavior changed during the review fixes.

## Checklist Summary

Use this as a quick reference during each round:

- [ ] Classification logic: variable combinations verified, false-positive cases tested
- [ ] Security-sensitive code: negative tests >= positive tests
- [ ] No unnecessary allocations in hot paths
- [ ] API is straightforward — no surprising behavior for callers
- [ ] Tests use idiomatic caller patterns
- [ ] Docs/specs match the implementation
- [ ] All tests pass
- [ ] Benchmarks within acceptable threshold (if applicable)
