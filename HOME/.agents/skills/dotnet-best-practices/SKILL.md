---
name: dotnet-best-practices
description: 'Ensure .NET/C# code meets best practices for the solution/project.'
---

# .NET/C# Best Practices

Your task is to ensure .NET/C# code in ${selection} meets the best practices specific to this solution/project. This includes:

## Documentation & Structure

- Create comprehensive XML documentation comments for all public classes, interfaces, methods, and properties
- Include parameter descriptions and return value descriptions in XML comments
- Follow the established namespace structure: {Core|Console|App|Service}.{Feature}

## Design Patterns & Architecture

- Use primary constructor syntax for dependency injection (e.g., `public class MyClass(IDependency dependency)`)
- Implement the Command Handler pattern with generic base classes (e.g., `CommandHandler<TOptions>`)
- Use interface segregation with clear naming conventions (prefix interfaces with 'I')
- Follow the Factory pattern for complex object creation.

## Dependency Injection & Services

- Use constructor dependency injection with null checks via ArgumentNullException
- Register services with appropriate lifetimes (Singleton, Scoped, Transient)
- Use Microsoft.Extensions.DependencyInjection patterns
- Implement service interfaces for testability

## Resource Management & Localization

- Use ResourceManager for localized messages and error strings
- Separate LogMessages and ErrorMessages resource files
- Access resources via `_resourceManager.GetString("MessageKey")`

## Async/Await Patterns

- Use async/await for all I/O operations and long-running tasks
- Return Task or Task<T> from async methods
- Use ConfigureAwait(false) where appropriate
- Handle async exceptions properly

## Testing Standards

- Use MSTest framework with FluentAssertions for assertions
- Follow AAA pattern (Arrange, Act, Assert)
- Use Moq for mocking dependencies
- Test both success and failure scenarios
- Include null parameter validation tests

## Configuration & Settings

- Use strongly-typed configuration classes with data annotations
- Implement validation attributes (Required, NotEmptyOrWhitespace)
- Use IConfiguration binding for settings
- Support appsettings.json configuration files

## Semantic Kernel & AI Integration

- Use Microsoft.SemanticKernel for AI operations
- Implement proper kernel configuration and service registration
- Handle AI model settings (ChatCompletion, Embedding, etc.)
- Use structured output patterns for reliable AI responses

## Error Handling & Logging

- Use structured logging with Microsoft.Extensions.Logging
- Include scoped logging with meaningful context
- Throw specific exceptions with descriptive messages
- Use try-catch blocks for expected failure scenarios

## Performance & Memory Efficiency

- .NET 10 optimizations where applicable
- Implement proper input validation and sanitization
- Use parameterized queries for database operations
- Follow secure coding practices for AI/ML operations

### Allocation-Aware Design

- Prefer `ReadOnlyMemory<byte>` / `ReadOnlyMemory<char>` over `byte[]` / `string` when data is a slice of a longer-lived buffer — this avoids copying
- Use `ReadOnlySpan<T>` for transient comparisons and parsing; promote to `ReadOnlyMemory<T>` only when you need to store the reference beyond stack lifetime
- When a struct wraps owned bytes (e.g. a UTF-8 string key), use `ReadOnlyMemory<byte>` as the backing field instead of `byte[]` — this enables both copying construction (from `Span`) and zero-copy construction (from `Memory` slice of existing array)
- For per-item work in a loop (per-job, per-request, per-row), ask: "Is this allocation invariant across iterations?" If yes, hoist to a shared cache or `static readonly` field
- For small temporary buffers (≤ 128 elements), prefer `stackalloc`; for larger ones, use `ArrayPool<T>.Shared`
- Avoid `new T[]`, `new List<T>()`, `new Dictionary<K,V>()` inside hot loops — pre-allocate and `.Clear()` or use fixed-size field arrays with element overwrite
- Cache computed results that depend only on immutable input (e.g. line offsets from source text, parsed expressions by content hash)
- When the same string is constructed repeatedly with identical content (e.g. diagnostic messages for the same entity), cache the last result and compare input bytes before regenerating

## Code Quality

- Ensure SOLID principles compliance
- Avoid code duplication through base classes and utilities
- Use meaningful names that reflect domain concepts
- Keep methods focused and cohesive
- Implement proper disposal patterns for resources

## Modern C# Features

- Use the latest C# syntax available (C# 13 or later)
- Use `using` declarations for automatic disposal
- Use file-scoped namespaces to reduce indentation
- Use collection literals where applicable
- Use pattern matching and switch expressions
- Use raw string literals for multi-line strings, avoid using StringBuilder for simple cases.

## Naming Conventions

- Follow .NET coding guidelines for base conventions
- Use `PascalCase` for constant names
- Do NOT use `_` or `s_` prefixes for fields
- Prefer the use of `var` for local variables

## Unit Tests

- All sorting algorithms must have comprehensive unit tests
- Tests should cover edge cases (empty arrays, single elements, duplicates, etc.)
- Test file naming: `{AlgorithmName}Tests.cs`
- Use xUnit framework conventions
