# .NET Harness for the Micro-Optimization Loop

Concrete, validated setup for running the loop with BenchmarkDotNet (0.15+),
including disassembly export, intrinsics tiers, and shipping patterns.

## Contents

1. Benchmark project setup
2. Program.cs config (`--micro` mode)
3. Benchmark class skeleton (variants + correctness gate)
4. Running and reading results
5. Reading .NET disassembly
6. Intrinsics / TFM availability matrix
7. Shipping: tiered dispatch, parity tests, NativeAOT
8. Before/after end-to-end measurement

## 1. Benchmark project setup

Console project, latest TFM, BenchmarkDotNet package. Self-contained: copy the
target function and its internal helpers into the benchmark (internals usually
aren't visible anyway, and copies keep variants diff-friendly). Add
`<AllowUnsafeBlocks>true</AllowUnsafeBlocks>` only if a variant needs `fixed`
(most ref/`Unsafe.*` code does not).

## 2. Program.cs config

Support two modes: the repo's existing quick config, and a `--micro` mode with
meaningful statistics + disassembly. The 1-iteration quick configs common in
repos are useless at ns scale.

```csharp
var micro = Array.IndexOf(args, "--micro") >= 0;
args = Array.FindAll(args, static a => a != "--micro");

var config = micro
    ? ManualConfig.CreateMinimumViable()
        .AddDiagnoser(MemoryDiagnoser.Default)
        .AddDiagnoser(new DisassemblyDiagnoser(new DisassemblyDiagnoserConfig(
            maxDepth: 3,
            printSource: true,
            exportGithubMarkdown: true,
            exportCombinedDisassemblyReport: true)))
        .AddExporter(MarkdownExporter.GitHub)
        .AddExporter(JsonExporter.Full)
        .AddJob(Job.Default.WithWarmupCount(3).WithIterationCount(15))
    : /* keep the repo's existing quick config */;

BenchmarkSwitcher.FromAssembly(Assembly.GetEntryAssembly()!).Run(args, config);
```

CLI mutators work on top: `--warmupCount 3 --iterationCount 15 --launchCount 3`
override job settings without touching code (verify via the
`IterationCount=...` line in the output header). `--filter *ClassName*` scopes
the run.

## 3. Benchmark class skeleton

```csharp
public class MyKernel
{
    [Params("small", "large")]     // realistic sizes from the real caller
    public string Scenario { get; set; } = "small";

    private byte[] _input = [];
    private byte[] _output = [];

    [GlobalSetup]
    public void Setup()
    {
        // build deterministic inputs (seeded Random), include zero bytes to
        // exercise skip paths
        VerifyAllVariantsMatchBaseline();   // throws on mismatch => run aborts
    }

    [Benchmark(Baseline = true)]
    public byte V1_Baseline() { Variants.V1_Baseline(_input, _output); return _output[0]; }

    [Benchmark]
    public byte V2_SomeHypothesis() { Variants.V2_SomeHypothesis(_input, _output); return _output[0]; }
    // ... one method per variant; return derived value to defeat DCE
}
```

Variants live in a `static class Variants` (static methods keep per-variant
disassembly self-contained and attributable). The gate iterates
`(size, seed)` combos plus all-zero / all-0xFF / minimum-size inputs and
compares `SequenceEqual` against V1, with a delegate list so adding a variant is
one line.

Notes that bite:
- `stackalloc` spans are zero-initialized unless `SkipLocalsInit` is set — some
  variants rely on the zeroed tail; check before enabling `SkipLocalsInit`.
- Don't cache things per-variant in ways that leak between benchmarks; static
  lazy tables are fine (they're part of the design being measured — warmup
  builds them).

## 4. Running and reading results

Run in the background (a 10-variant × 2-scenario run with disassembly takes
5-10 minutes):

```
dotnet run -c Release -- --micro --filter *MyKernel*
```

Results land in `BenchmarkDotNet.Artifacts/results/`:
- `*-report-github.md` — summary table (Mean, Ratio, Code Size, Allocated)
- `*-report-full.json` — machine-readable
- `*-asm.md` — JIT disassembly per benchmark, source-annotated

Compare Ratio within a scenario only. Cross-run drift is ±5-10% (alignment);
same-run comparisons decide accept/refute.

## 5. Reading .NET disassembly

Symptoms and what they mean in RyuJIT output:

| Pattern in `*-asm.md` | Meaning | Fix |
|---|---|---|
| `cmp`/`jae` → `call CORINFO_HELP_RNGCHKFAIL` in loop | bounds check per iteration | prove range (loop bound == span length) or `MemoryMarshal.GetReference` + `Unsafe.Add` |
| `test byte ptr [..],1` + `je` in loop | static-init (cctor) guard | touch statics once before the loop / restructure |
| `mov [rbp+..]` / `mov [rsp+..]` in inner loop | register spills | fewer live locals in the loop body |
| `call` to a small method in loop | inlining failure | `AggressiveInlining`, simplify signature (spans by value re-materialize) |
| repeated `mov rax, <handle>; mov rax,[rax]` | static field base reload | hoist `ref var x = ref MemoryMarshal.GetArrayDataReference(arr)` before loop |
| `movzx` churn re-reading just-written bytes | byte round-trips through memory | keep intermediates in `int`/vector registers |

For loop cloning (fast + slow copies of the loop), find which copy actually runs
(the guarded fast clone) before judging.

## 6. Intrinsics / TFM availability matrix

| API | TFM | Notes |
|---|---|---|
| `Span`, `MemoryMarshal.GetReference`, `Unsafe.Add` | netstandard2.0+ (via System.Memory/Unsafe packages, often transitive) | portable scalar kernels |
| `MemoryMarshal.GetArrayDataReference` | net5+ | use `GetReference(arr.AsSpan())` downlevel |
| `Vector128/256.LoadUnsafe/StoreUnsafe` | net7+ | |
| `Ssse3` (PSHUFB), `Sse2` | netcoreapp3.0+; use net8.0 gate | in NativeAOT's default x86-64-v2 baseline → compiled statically |
| `Avx2` | netcoreapp3.0+ | above AOT baseline → startup cpuid check |
| `Gfni` (`GaloisFieldAffineTransform`) | **net10.0** | `Gfni.V256` for 256-bit; Zen 4 / Ice Lake+ |
| `AdvSimd` (ARM64) | netcoreapp3.0+ | x86 classes report `IsSupported == false` on ARM; guarded branches get trimmed by ILC |

Domain-instruction cheat sheet: GF(2^8) multiply → `Gfni.GaloisFieldAffineTransform`
(precompute per-constant 8-byte bit matrices; identity = `0x0102040810204080`;
convention: qword byte `(7-i)` = row for result bit `i`). Carryless multiply →
`Pclmulqdq`. Byte-table lookup ≤16 entries → `Ssse3.Shuffle` nibble-split
(two 16-byte tables per constant: `c·x = TLo[x&0xF] ^ THi[x>>4]`; zero rows make
zero inputs free).

## 7. Shipping: tiered dispatch, parity tests, NativeAOT

Dispatch shape (in the library, entry point keeps the guards, kernels are
`internal` for direct testing):

```csharp
public static void Kernel(ReadOnlySpan<byte> data, Span<byte> output, int param)
{
    // argument guards here, once
#if NET8_0_OR_GREATER
    if (param <= VectorLimit && Ssse3.IsSupported) { KernelSimd(...); return; }
#endif
    KernelScalar(...);   // best portable variant, all TFMs + ARM64
}

// in a partial class file wrapped in #if NET8_0_OR_GREATER:
internal static void KernelSimd(...)
{
#if NET10_0_OR_GREATER
    if (Gfni.IsSupported) { KernelGfni(...); return; }
#endif
    KernelSsse3(...);    // covers AVX2-only CPUs too if wider vectors lost
}
```

- Lazily built per-parameter tables: publish with
  `Volatile.Write(ref cache[i], table)`. On net8+ plain reference stores already
  have release semantics per the documented .NET memory model, but netstandard
  targets can run on runtimes without that guarantee and the fix is free. Plain
  reads are fine (address-dependent loads).
- Probe the full documented parameter range for degenerate math: e.g. RS
  generator polynomials are all-nonzero for eccCount ≤ 254 (MDS argument) but
  degenerate at 255 — represent "unrepresentable" with a cache sentinel and fall
  back to the naive kernel instead of throwing.
- Parity tests (xUnit): each kernel directly vs a naive reference, sizes ×
  seeds × edge inputs, boundary sizes around register-width splits (16/17),
  sizes above the vector limit, and max parameter values. Guard with
  `Assert.SkipUnless(Ssse3.IsSupported, ...)` (xunit.v3).
- NativeAOT verification: `dotnet publish -p:PublishAot=true`, run, and compare
  output hashes against the JIT run (compare the *computed data*, not rendered
  images — text rendering differs). ILC accepts `-p:IlcInstructionSet=gfni` etc.
  to bake fast paths in; otherwise above-baseline ISAs get a startup cpuid check.

## 8. Before/after end-to-end measurement

For PR numbers:

- Same benchmark code on both sides: keep the end-to-end benchmark file
  untracked (or on both branches), measure `main` vs the feature branch by
  `git checkout` between runs.
- Use `--launchCount 3` (plus 15 iterations): separate process launches average
  code-layout noise, which otherwise produces ±5-10% phantom deltas between
  branch builds. Without launch averaging, single runs can even show phantom
  regressions.
- Scenarios: small / typical / large / max-ECC-share (or the domain equivalent)
  so reviewers see the spread; report allocations too.
- Present both tables in the PR: kernel-level speedup (the interesting one) and
  end-to-end delta (the honest one), plus one line explaining the gap (share of
  total time).
