# Language Support in Lux

Lux is designed to be language-agnostic, allowing you to build agents in your preferred programming language. This guide provides an overview of language support in Lux and how to use different programming languages in your agents.

## Currently Supported Languages

### Python Integration
[Learn more about Python integration](language_support/python.livemd)

Python is a first-class citizen in Lux, with deep integration into the framework. You can:
- Write Python code directly in your Elixir files using `~PY` sigils
- Add custom Python modules under `priv/python` and import them
- Use any Python package through pip/poetry
- Leverage Python's rich ML and data science ecosystem

> 🔥 **Coming Soon**: Define Prisms, Beams, and other Lux components entirely in Python! This will allow you to write your agents' logic completely in Python while still leveraging Lux's powerful orchestration capabilities.

### Node.js/JavaScript Integration
[Learn more about Node.js integration](language_support/nodejs.livemd)

Node.js integration allows you to leverage the vast JavaScript ecosystem:
- Write JavaScript/TypeScript code using `~JS` sigils
- Use NPM packages in your agents
- Support for modern ES modules and async/await
- Full access to Node.js APIs

### Rust Integration (Experimental)

Initial Rust support is now available under `priv/rust/`. The
`lux_core` crate hosts the early Rust primitives — most notably the
**Lux Rust Testing Framework** in `lux_core::testing` — so contributors
can develop Rust-side components with the same test-first discipline
used on the Elixir and Python sides.

You can:

- Run the Rust test suite from the project root with `mix rust.test`
  (forwards arguments to `cargo test --workspace`)
- Add new crates under `priv/rust/` and list them in the workspace
  manifest
- Use the dependency-free helpers in `lux_core::testing` (`Recorder<T>`,
  `assert_eq_with_context`, `assert_runs_within`, `sample_signal`) for
  deterministic unit and integration tests
- See `priv/rust/README.md` for the full layout, prerequisites and
  contributor workflow

The next phase will add `rustler`-based NIFs so Prisms, Beams and
Signals can be implemented natively in Rust.

### Future Language Support
Want to add support for your favorite language? Lux provides a Language Integration Protocol that allows you to:
- Add new language runtimes
- Define type conversion rules
- Handle package management
- Implement error handling

Check out our [Contributing Guide](contributing.md) for details on adding language support.

## Best Practices

1. **Choose the Right Language**
   - Use Python for ML/AI tasks and data processing
   - Use Node.js for web integration and text processing
   - Use Elixir for coordination and state management
   - Use Rust for performance-critical components and native extensions

2. **Package Management**
   - Add custom Python modules under `priv/python/`
   - Use `poetry` for Python dependency management
   - Use `npm`/`yarn` for Node.js dependencies
   - Use `cargo` for Rust dependencies (workspace under `priv/rust/`)
   - Follow the language's best practices for versioning

3. **Performance Considerations**
   - Minimize cross-language calls
   - Batch operations when possible
   - Use appropriate data serialization
   - Consider memory usage patterns

4. **Security**
   - Validate all inputs
   - Control package versions
   - Follow security best practices for each language
   - Implement proper sandboxing

## Examples

Check out these examples of language integration:

- [Trading System](trading_system.livemd): Uses Python for data analysis
- [Content Creation](running_a_company.livemd): Uses JavaScript for text processing
- [Research Assistant](multi_agent_collaboration.livemd): Combines multiple languages

## Contributing

Want to add support for a new language? Check our [Contributing Guide](contributing.md) and:

1. Review the Language Integration Protocol
2. Create a proof of concept
3. Add comprehensive tests
4. Document the integration
5. Submit a pull request

For detailed examples and up-to-date documentation, visit [hexdocs.pm/lux](https://hexdocs.pm/lux). 