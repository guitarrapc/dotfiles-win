---
name: dotnet-performance-discipline
description: >
  Standing rules for writing allocation-conscious, high-performance C#/.NET.
  Covers pooled-buffer ownership (who may hold an ArrayPool rental, and what may
  cross an API boundary), choosing between Span/Memory/array, stackalloc byte
  budgets, zero-copy UTF-8 and transient-string avoidance, hot-path prohibitions
  (LINQ, closures, regex, growable collections), immutable lookup structures,
  bounded error paths, async state-machine size, and how to verify an allocation
  change without trusting a stale baseline. Use when writing or reviewing code on
  a hot path, when deciding whether something is allowed to allocate, when a type
  wraps a rented or borrowed buffer, when a struct or record struct holds an
  array, or when an allocation benchmark moves. For the iterative
  benchmark-and-disassembly loop that finds the fastest implementation of one
  function, use dotnet-micro-optimization instead; this skill is the rule set,
  not the measurement workflow.
---

# .NET Performance Discipline

Rules for code on a hot path — anything that runs per item, per request, per row, per token, or per element of an unbounded input. They are defaults, not laws: deviate when a measurement says so, and record the measurement.

Two things are correctness properties here, not preferences: **allocation rate** and **who owns a borrowed buffer**. The rest is optimization.

## 1. Ownership of pooled and borrowed buffers

A rented buffer has exactly one owner: the scope that called `Rent` and is obliged to call `Return`. Whatever crosses an API boundary must make that ownership visible in its type.

### Never keep a rented array in a `struct` or `record struct` field

A struct copies silently — on assignment, argument passing, `with` expressions, array and collection storage, and closure capture. Every copy carries the array reference and none carries the obligation to return it, so a stale copy can read or write a buffer another copy already returned. Nothing throws: the pool hands the same array to an unrelated caller and both sides continue on plausible-looking data. The failure surfaces far from its cause, as a wrong result rather than a crash.

### `Memory<T>`/`ReadOnlyMemory<T>` over a rented array is that same defect

It is a copyable struct holding the array, and unlike `Span<T>` it can be stored in a field, captured by a lambda, and hoisted into an async state machine. Passing one across an API boundary silently moves the buffer somewhere the compiler no longer restricts, so locality degrades from a guarantee to a convention. **Do not widen a parameter to `Memory<T>` merely to make a pooled buffer fit through an async signature.**

`Memory<T>` is correct for a *GC-owned* buffer that genuinely must be stored or awaited over. The defect is `Memory<T>` **over pooled storage**.

### Ranked options — take the first that fits

Each later option gives up a guarantee the earlier one had.

**0. Check whether a shared buffer is needed at all.** When a buffer exists only to carry values from one stage to the next, check whether those values can travel in a domain object both stages already receive. Removing the buffer dissolves the ownership question instead of relocating it, and costs nothing at runtime.

**1. The caller lends a `Span<T>`.** The owner rents and returns inside one scope with `try`/`finally` and passes `Span<T>`/`ReadOnlySpan<T>` down. The callee borrows and cannot outlive the loan: the compiler rejects storing a `Span<T>` in a field, capturing it in a closure, or holding it across an `await`. Locality becomes a compile-time property rather than a review obligation.

```csharp
// ✅ One owner rents and returns; every consumer only borrows.
var rented = ArrayPool<int>.Shared.Rent(count);
try
{
    var scratch = rented.AsSpan(0, count);
    var planned = Plan(items, scratch);
    Project(items, scratch, planned);
}
finally
{
    ArrayPool<int>.Shared.Return(rented);   // clearArray: true when T holds references
}
```

**2. When the buffer is needed on both sides of an `await`, split the operation.** Keep the buffer in synchronous plan and project phases that take spans, and give the async I/O phase its own inputs and results with no caller buffer. The awaits then sit between the borrows instead of across them. This also shrinks the async state machine (see §7).

**3. Last resort — a class that owns the rental.** Only when the rental must genuinely span several async calls issued by a caller that cannot be restructured. Costs one object per scope; justify in the type's documentation why options 0–2 were ruled out. Such a type must:

- keep the array in a private field and expose it **only** as `Span<T>`, never as `Memory<T>` or as the array itself;
- drop the field *before* returning the rental in `Dispose`, so an access that outlives the scope throws `ObjectDisposedException` instead of reading recycled pool storage;
- tolerate repeated `Dispose`;
- be created with `using` at the single owning scope.

```csharp
// ✅ Fail-loud owner. Span accessor keeps borrows from escaping.
internal sealed class Workspace : IDisposable
{
    private Item[]? items;
    public Workspace(int count) { items = ArrayPool<Item>.Shared.Rent(Math.Max(count, 1)); Length = count; }
    public int Length { get; }
    public Span<Item> Items => (items ?? throw new ObjectDisposedException(nameof(Workspace))).AsSpan(0, Length);
    public void Dispose()
    {
        var returned = items;
        if (returned is null) return;
        items = null;                       // invalidate before returning
        returned.AsSpan(0, Length).Clear();
        ArrayPool<Item>.Shared.Return(returned);
    }
}
```

Add a regression test proving a disposed owner rejects access, and that consumers refuse to write through it.

### Other pooling rules

- Return in a `finally`, and keep the `Rent` adjacent to the `try` so the window where an exception can leak the rental stays as small as possible.
- Clear the used range when `T` contains references, otherwise the pool keeps them alive. `Return(array, clearArray: true)` clears everything; clearing only `[0..used]` is enough and cheaper, because `Return` already cleared the rest.
- When growing a pooled buffer, rent the replacement, copy, return the old one, then reassign — and make sure the `finally` returns the *current* buffer, not a captured stale one.
- Never let pooled storage escape into a returned domain result. Copy out with `ToArray()` over the used range.

## 2. Choosing Span, Memory, or array

| Use | When |
|---|---|
| `Span<T>` / `ReadOnlySpan<T>` | Transient contiguous data whose ownership does not escape the synchronous region. The default. |
| `Memory<T>` / `ReadOnlyMemory<T>` | A **GC-owned** buffer that must be stored in a field or held across an `await`. Never over pooled storage. |
| `T[]` | The value is part of the returned result and the caller owns it. |

Prefer accepting `ReadOnlySpan<T>` in APIs that only read: it accepts arrays, spans, stack buffers, and slices without forcing an allocation at the call site.

## 3. Stack allocation budget

Set the `stackalloc` limit by **total byte size and element type**, never by a universal element count and never from input length. A few hundred bytes is a reasonable ceiling; 1 KB is a lot for a method that may sit deep in a recursive or async call chain.

```csharp
// ❌ Unbounded — stack overflow on long input, and input is usually attacker-influenced
Span<char> chars = stackalloc char[value.Length];

// ✅ Fixed budget with a pool fallback
const int MaxStackChars = 128;                 // 256 bytes
char[]? rented = null;
Span<char> chars = value.Length <= MaxStackChars
    ? stackalloc char[MaxStackChars]
    : (rented = ArrayPool<char>.Shared.Rent(value.Length));
try
{
    var count = Encoding.UTF8.GetChars(value, chars);
    // span-based work
}
finally
{
    if (rented is not null) ArrayPool<char>.Shared.Return(rented);
}
```

Never `stackalloc` inside a loop — the allocation is per *method frame*, so it accumulates until the method returns.

## 4. Zero-copy text and transient strings

- Compare UTF-8 without decoding: `Utf8JsonReader.ValueTextEquals("name"u8)`, `span.SequenceEqual("value"u8)`, and `"literal"u8` constants (which are static data, not allocations).
- Keep source-backed text as an offset/length slice over the owned source buffer rather than copying each value out. Decode once, at the boundary that needs ownership.
- A `string` is legitimate for: a public result model, a cache key, a network request, configuration, output, and exception messages. It is not legitimate as an intermediate in a per-item loop.
- Do not normalize or decode the same value twice — carry the resolved form forward.
- `string.Concat`, interpolation, `Substring`, `Split`, `ToLower`/`ToUpper`, and `Trim` all allocate. Span equivalents (`AsSpan()`, `MemoryExtensions.Trim`, `Equals(..., StringComparison.OrdinalIgnoreCase)`) usually do not.

## 5. Hot-path prohibitions

- **No LINQ.** Every operator allocates an enumerator, usually a closure, and often an intermediate collection, and it blocks devirtualization.
- **No closures that capture.** A lambda capturing a local allocates a display class per call. Prefer static lambdas (`static x => ...` — the compiler will error if it captures), explicit state parameters (`Parallel.For`, `Dictionary.GetValueOrDefault`-style overloads taking state), or plain loops.
- **No regex** for structural matching (property names, identifiers, prefixes) unless a benchmark proves it. Span scanning is faster and allocation-free.
- **No growing collections per item.** Estimate capacity up front, or reuse pooled/fixed storage and `Clear()` it.
- **No interface or virtual dispatch per item.** Resolve polymorphism once, before the loop, at a registration or construction boundary.
- **No boxing.** Watch for `struct` implementing an interface used through the interface, `object` parameters, non-generic collections, and struct enumerators consumed through `IEnumerable<T>`.

## 6. Immutable lookup structures

Build once at startup or registration, never per item.

- `FrozenDictionary<TKey, TValue>` when the lookup must return a canonical value (for example, mapping a case-insensitive key to its canonical casing).
- `FrozenSet<T>` when the question is membership only.
- `FrozenDictionary`/`FrozenSet` cost more to construct and less to query than `Dictionary`/`HashSet`; use them only for read-mostly tables that outlive many queries.
- Use the span-based lookup overloads (`GetAlternateLookup<ReadOnlySpan<char>>()`) so callers do not have to materialize a `string` to query.
- Do not retain a second copy of the construction input once the lookup is built.

## 7. Loops, inlining, and async state machines

- Hoist values that are invariant across iterations — including `Count`/`Length` reads through an interface, property chains, and repeated dictionary lookups.
- Iterate spans directly (`foreach` over `Span<T>` is allocation-free and bounds-check-friendly). `foreach` over `List<T>` is allocation-free; over `IEnumerable<T>` it is not.
- `[MethodImpl(MethodImplOptions.AggressiveInlining)]` only for small methods on a **measured** hot path. Keep it only while a benchmark justifies it; forced inlining grows code size and can inhibit better JIT decisions.
- **Async state machines are allocations.** Every local alive across an `await` becomes a field of a heap-allocated state machine. Moving a loop and its locals into a synchronous helper method shrinks it. So does replacing a 16-byte `Memory<T>` field with an 8-byte reference. An async method that usually completes synchronously should return `ValueTask` and take a fast path that never awaits.
- Prefer `ConfigureAwait(false)` in library code, and avoid `async` methods that only forward — return the inner task directly when there is no work after the await.

## 8. Error and edge paths

Invalid input may allocate for messages and diagnostics, but work must stay bounded for pathological input, which is where denial-of-service lives.

- Bound input length and candidate count *before* expensive work.
- Decode only the prefix that will actually be displayed, not the whole pathological value.
- Keep display limits separate from validity rules.
- Short-circuit on byte length before decoding or searching.

```csharp
// ✅ Bounded display of pathological input
display = span.Length > MaxDisplayLength
    ? string.Concat(Encoding.UTF8.GetString(span[..MaxDisplayLength]), "...")
    : Encoding.UTF8.GetString(span);
```

## 9. Verifying an allocation change

Use BenchmarkDotNet with `[MemoryDiagnoser]` in a Release build, and compare against a baseline you trust.

**Do not trust a stored baseline file.** Committed benchmark reports go stale silently — the code moved on, or the job settings differed. Signs it is stale: the row count does not match the current benchmark class, or the job header (`IterationCount`, `WarmupCount`) differs from what you are running. Re-measure both sides:

```bash
# Baseline from committed code, without disturbing the working tree
git worktree add --detach /tmp/baseline HEAD
# build and run the same filter in both trees, same --warmupCount/--iterationCount
git worktree remove --force /tmp/baseline
```

Reading the result:

- Separate **required result allocations** (the returned model, rendered output, persisted records) from **avoidable temporaries** inside repeated loops. Only the second kind is a defect.
- Attribute every byte of a delta. "+32 B" should map to a specific object; if you cannot name it, you do not understand the change yet.
- A per-process constant cost and a per-item cost are different things. Prefer a fixed cost that does not scale with input over a smaller cost that does.
- Timing on benchmarks that touch the filesystem or network is noisy. Before believing a regression, raise the iteration count and check whether the confidence intervals still separate.
- Reject unexplained regressions in either mean time or allocated bytes.

For the iterative loop of hypothesis → variant → measure → read disassembly, use **dotnet-micro-optimization**.
