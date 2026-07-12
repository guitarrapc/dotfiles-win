---
name: dotnet-micro-optimization
description: >
  Benchmark-driven micro-optimization loop: find the fastest implementation of a
  hot function by measuring one-hypothesis-per-variant implementations under a
  benchmark harness, reading JIT/native disassembly to explain the numbers, and
  iterating until improvements fall below 2-3%. Use this whenever the user wants
  to optimize a small hot function, find the fastest implementation of something,
  compare implementation variants, set up micro benchmarks (BenchmarkDotNet,
  criterion, google-benchmark), analyze JIT assembly or machine code, vectorize a
  loop with SIMD/intrinsics, or asks "why is this slow" / "make this faster" at
  the function level — even if they never say the word "benchmark". Also use it
  when porting an optimization winner back into a library (runtime dispatch,
  correctness parity tests, before/after end-to-end measurement for a PR).
---

# Micro-Optimization Loop

A disciplined search for the fastest implementation of a small hot function.
The output is not just faster code: it is a measured, correctness-gated,
disassembly-explained result with a findings log that says *why* the winner wins
and which plausible ideas were refuted.

The single most important mindset: **hypotheses are cheap, measurements decide.**
Roughly a third of well-reasoned optimization hypotheses turn out to be wrong
(caching that loses to recomputation, wider vectors that lose to narrower ones).
The loop exists to catch those cheaply instead of shipping them.

## When to use / not use

Use when the hot function is already known (profiler, benchmark, or obvious
algorithmic core) and is small enough to reimplement in variants — roughly one
screen of code, called thousands+ times.

Do not start here when the bottleneck is unknown (profile end-to-end first) or
when an asymptotic/algorithm change is still on the table (do that first; this
loop tunes constants, and a better algorithm invalidates all tuning).

Estimate the ceiling before starting: if the function is X% of end-to-end time,
even an infinite speedup buys only X% (Amdahl). Say this to the user up front —
it sets expectations for the final PR numbers.

## Where the benchmark lives

Ask or infer where benchmark code belongs. Some repos have an in-tree benchmark
project; some users keep a private benchmarks repo and want **no traces** in the
library repo. Variants copy internal code, so the benchmark can usually be fully
self-contained (no project reference) — prefer that: it makes variants
diff-friendly and keeps the loop independent of library internals/visibility.

## Rules for the benchmark harness

1. **Baseline is a faithful copy.** `V1_Baseline` copies the current production
   code verbatim, including internal helpers it depends on. Every ratio is
   relative to it.
2. **One hypothesis per variant.** Each `Vn_<Description>` changes exactly one
   thing relative to a named parent variant and states the hypothesis in a doc
   comment. Composed changes make results unattributable.
3. **Correctness gate before measurement.** Setup must compare every variant's
   output against the baseline across representative sizes, multiple seeds, and
   edge inputs (all-zero, minimum sizes, boundary lengths) and throw on mismatch.
   A fast wrong answer is not a result. This gate is also what lets you use
   "unsafe-looking" math (log domains, bit-matrix tricks, lookahead recurrences)
   with confidence.
4. **Realistic workloads.** Parameterize with the sizes the real caller
   produces, not powers of two. Include at least one small and one large case —
   winners frequently differ by size, and the shipped code may need a size
   switch or per-size verdicts.
5. **Defeat dead-code elimination.** Benchmark methods return a value derived
   from the output.
6. **Statistically meaningful runs.** A 1-iteration "quick" config is useless at
   nanosecond scale. Use ~3 warmups / ~15 iterations, plus memory diagnostics
   and disassembly export. See the ecosystem reference for concrete config.

## The loop

```
┌─> 1. hypothesize   add ONE new variant (one hypothesis, doc-commented)
│   2. verify        build; correctness gate must pass
│   3. measure       run the harness (background it; runs take minutes)
│   4. read          summary table -> ranking, ratio, allocations
│                    disassembly   -> machine code per variant
│   5. analyze       explain WHY the numbers differ using the asm; a number
│                    without an asm-level explanation is not yet understood
└── 6. iterate       record verdict (confirmed/refuted) in the findings log,
                     form the next hypothesis from the asm evidence
    7. stop          when the round's best improvement is < 2-3% per scenario,
                     or remaining hypotheses have negative expected value
                     (e.g., tables that would blow L1) — say so explicitly
    8. ship          port the winner; see "Shipping" below
```

Keep refuted variants in the file. They are the search log that stops the loop
from re-testing dead ends, and refutations are often the most valuable findings.

### Reading the numbers

- Compare **within one run only**. Cross-run means drift ±5-10% from code
  layout/alignment; accept/refute decisions need same-run ratios.
- Treat < 2-3% as noise even with good iteration counts; re-run before believing.
- Watch allocations: hot kernels should stay at zero; any allocation is a
  regression. One-time lazily built tables are fine (they amortize) but must be
  called out as a documented trade-off.
- Winners must win **per scenario**. A variant that wins large inputs but loses
  small ones (per-call setup cost) needs a size cutoff or per-size dispatch.

### Disassembly checklist

Read the winner's and the baseline's disassembly and look for, in rough order of
impact:

- **Bounds checks**: compare+branch to a range-check-failure helper reachable
  from the inner loop. Remove by letting the compiler prove ranges or by
  pointer/ref arithmetic — but only after algorithmic waste is gone.
- **Inlining failures**: any `call` in the hot loop you expected inlined.
- **Loop-invariant work**: address recomputation, table-base reloads, value
  recomputes inside the loop — hoist.
- **Register spills**: stack traffic (`mov [rsp+..]`) inside the inner loop;
  reduce live locals.
- **Static-init / lazy guards**: type-init checks or null checks per iteration.
- **Branches per iteration**: data-dependent branches are fine when the data
  rarely takes them, hostile when it's random. Tables often absorb branches for
  free (e.g., a zero input row that yields a zero contribution).
- **Code size vs speed**: a big method can lose on icache despite fewer ops.

### The hypothesis ladder

Escalate in this order — each rung is usually worth more than everything below
it, and later rungs only pay once the earlier waste is gone:

1. **Remove per-call algorithmic waste.** Anything that depends only on a small
   set of parameters (generator polynomials, shift tables, format constants) can
   be computed once and cached per parameter value. This is routinely worth more
   than all instruction-level tricks combined.
2. **Restructure lookups.** Move work into precomputed tables; convert
   multi-step math into single lookups (log-domain, direct multiplication rows).
3. **Bounds-check / ref tricks, unrolling.** Worth ~10-20% each, only after 1-2.
4. **SIMD the data plane.** Vectorize the bulk operation. Know the domain
   idioms (e.g., byte-table lookups via nibble-split shuffles rather than
   gathers). Try multiple widths — wider is NOT automatically faster; measure
   128-bit×2 vs 256-bit.
5. **Registerize state.** Keep small hot state (≤ a vector or two) in registers
   across the whole loop instead of round-tripping memory; store-to-load
   forwarding on the dependency chain is expensive.
6. **Attack the serial dependency chain.** Once throughput work is cheap, the
   recurrence (state[i+1] = f(state[i])) is the wall: lookahead (process k
   elements per step), linearize the recurrence into XOR/parallel-lookup form if
   the math is linear, software-pipeline so heavy updates fall off the critical
   chain, precompose chained linear maps into single tables (the multi-bit CRC
   trick).
7. **Domain instructions.** Check for a hardware instruction that does the core
   op directly (GFNI for GF(2^8), PCLMUL for carryless multiply, CRC32, AES,
   POPCNT...). One instruction can beat every table formulation; check ISA
   extensions before exhausting table tricks.
8. **Shave per-call fixed costs.** At tens of ns, pointer chases, null checks,
   and guard branches are first-class targets: fuse tables behind one pointer;
   in the real port, hold per-parameter state in an encoder object across calls.

### Principles that keep proving true

- Caching pays only when it removes work from the *serial chain*; caching what
  the CPU rebuilds in parallel for free is a loss (load latency + pointer chase
  can exceed a handful of ALU ops).
- Deeper lookahead only wins once each scalar step is at its load-latency floor.
- "Latency doesn't matter off the critical chain" does not make uops free —
  throughput still binds.
- Statics whose address the compiler embeds are already free; "fusing" them into
  a per-parameter blob can make things slower.
- Correctness gates let you be aggressive. Every exotic transform (linearized
  recurrences, bit-matrix conventions) was safe to try because a mismatch threw
  before any measurement.

## Findings log

Maintain a findings log next to the benchmark (e.g. `MICRO_OPTIMIZATION.md`):
per round, record the hypothesis, the same-run numbers, the verdict
(CONFIRMED/REFUTED), and the asm-level explanation; end with a full result table
(every variant × every scenario from one final run) and a lessons list. This is
what makes the next optimization loop start from knowledge instead of zero.

## Shipping the winner

- **Tiered runtime dispatch.** Ship the fastest kernel per capability with
  fallbacks: e.g. newest-ISA kernel → common-SIMD kernel → portable scalar
  kernel, selected by `IsSupported`-style checks (and compile-time TFM/feature
  gates where APIs don't exist downlevel). The scalar fallback should itself be
  the best portable variant, not the old code.
- **Parity tests in the library.** Recreate the correctness gate as unit tests:
  each kernel (called directly, capability-guarded) vs a naive reference
  implementation, across sizes/seeds/edges — including sizes the fast paths
  reject, and pathological parameter values outside the primary domain (probe
  the full documented input range; degenerate cases can exist at the extremes —
  fall back gracefully rather than throwing on them).
- **Honest end-to-end numbers.** Measure before/after through the public API
  (before = clean checkout/branch; after = the change; identical benchmark
  code, multiple process launches to average layout noise). Report both the
  kernel-level speedup and the end-to-end delta, and explain the gap (Amdahl).
- **Document trade-offs**: table memory (static + per-parameter, lazily built),
  zero per-call allocations, unsafe/intrinsics justification (each must be
  backed by a measured win; if the safe version is within noise, ship the safe
  version).
- Concurrency: publish lazily built tables with a release store
  (`Volatile.Write` or equivalent) — benign races on identical results are
  fine, torn publication is not.

## Ecosystem specifics

- **.NET / C#** (validated end-to-end): read `references/dotnet.md` for the
  BenchmarkDotNet + DisassemblyDiagnoser harness, intrinsics/TFM matrix,
  NativeAOT verification, and shipping patterns. Read it before setting up a
  .NET loop.
- **Other ecosystems**: the protocol transfers as-is; swap the harness —
  Rust: criterion + `cargo asm`/`--emit asm`; C/C++: google-benchmark +
  `perf annotate`/objdump; Go: `go test -bench` + benchstat + `go tool objdump`.
  Match the harness capabilities: statistical iterations, allocation tracking
  where relevant, and per-variant disassembly.
