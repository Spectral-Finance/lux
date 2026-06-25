# Language Support in Lux

Lux is designed to be language-agnostic, allowing you to build agents in your preferred programming language. This guide provides an overview of language support in Lux and how to use different programming languages in your agents.

## Currently Supported Languages

### Rust Integration
[Learn more about Rust integration](language_support/rust.livemd)

Rust integration provides high-performance native code execution with memory safety guarantees:
- Write Rust code and compile to a shared library for FFI access
- Use `Lux.Rust.eval/1` to execute Rust operations from Elixir
- Automatic type conversion between Elixir terms and Rust `LuxValue` types
- Structured error handling with categorized error types
- Ideal for compute-intensive tasks: cryptography, numerical algorithms, data processing

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

## Best Practices

1. **Choose the Right Language**
   - Use Rust for performance-critical and compute-intensive tasks
   - Use Python for ML/AI tasks and data processing
   - Use Node.js for web integration and text processing
   - Use Elixir for coordination and state management

2. **Package Management**
   - Add custom Rust code under `priv/rust/` and use Cargo
   - Add custom Python modules under `priv/python/`
   - Use `poetry` for Python dependency management
   - Use `npm`/`yarn` for Node.js dependencies
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
