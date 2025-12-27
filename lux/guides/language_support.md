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

### Rust Integration
[Learn more about Rust integration](language_support/rust.livemd)

Rust integration enables high-performance native code execution:
- Write Rust code that runs directly in the BEAM via NIFs
- Zero-copy data transfer for binaries
- Minimal latency function calls (nanoseconds vs milliseconds)
- Full type safety via the Rustler type system
- Access to Rust's rich ecosystem for performance-critical tasks

## Future Language Support

### Custom Language Integration
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
   - Use Rust for performance-critical and CPU-intensive components

2. **Package Management**
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