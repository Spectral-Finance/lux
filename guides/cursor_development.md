# Developing Lux with Cursor

Cursor is a powerful AI-enabled IDE that can significantly enhance your development experience with Lux. This guide will help you get started with using Cursor effectively for Lux development.

## Getting Started with Cursor

1. **Install Cursor**: Download and install Cursor from [cursor.sh](https://cursor.sh)
2. **Open Your Lux Project**: Open your Lux project directory in Cursor
3. **Enable Composer**: Press `Cmd/Ctrl + L` to open the Composer panel

## Key Cursor Features for Lux Development

### Composer Context

The Composer is Cursor's AI pair programming interface. To make it more effective for Lux development, you should provide it with relevant context:

```
You are an expert in Elixir, Python, Javascript, Typescript, Phoenix, Distributed Systems, GenServer, PostgreSQL, LLMs, and Agentic workflows.

In this project, we are building an open source library for general LLM-based agentic workflows and collaboration between agents.

Please follow these conventions:
- Write concise, idiomatic Elixir code
- Follow Phoenix conventions and best practices
- Use functional programming patterns
- Leverage pattern matching and guards effectively
- Follow the Elixir Style Guide
```

### Creating Lux Components

#### Creating Prisms

When creating new prisms, reference the existing prism examples and tests:
- `lib/lux/prisms/eth_balance_prism.ex`
- `test/lux/prisms/eth_balance_prism_test.exs`

Example prompt:
```
Create a new prism that [describe functionality]. Please follow the same structure as the eth_balance_prism.ex, including:
- Comprehensive documentation
- Input/output schemas
- Error handling
- Unit tests
```

#### Creating Beams

Reference the beams guide and examples when creating new beams:
- `guides/beams.md`
- Existing beam implementations

Example prompt:
```
Create a new beam that [describe functionality]. Please include:
- Proper beam configuration
- State management
- Error handling
- Integration with other components
```

#### Creating Lenses

When working with lenses, refer to:
- `guides/lenses.md`
- Existing lens implementations

Example prompt:
```
Create a new lens that [describe functionality]. Include:
- Input/output transformations
- Error handling
- Unit tests
```

## Best Practices

1. **Use Test-Driven Development**
   - Ask Composer to write tests first
   - Use the test file as context when implementing the component

2. **Leverage Code Examples**
   - Keep relevant example files open
   - Reference them in your prompts to Composer

3. **Iterative Development**
   - Break down complex components into smaller tasks
   - Use Composer for code review and improvements

4. **Documentation**
   - Ask Composer to include comprehensive documentation
   - Follow the existing documentation style

## Common Workflows

### Adding a New Feature

1. Open relevant guides and example files
2. Ask Composer to create tests first
3. Implement the feature with Composer's help
4. Review and refine the implementation
5. Add documentation

### Debugging

1. Open relevant test and implementation files
2. Provide Composer with error messages and context
3. Ask for specific debugging strategies
4. Implement fixes iteratively

### Code Review

1. Open the files to be reviewed
2. Ask Composer to:
   - Check for common issues
   - Suggest improvements
   - Verify test coverage
   - Review documentation

## Tips and Tricks

1. **Keep Context Fresh**
   - Regularly update Composer's context with relevant files
   - Include test files for better understanding

2. **Use Multi-Step Development**
   ```
   Step 1: "Create the test file for the new component"
   Step 2: "Implement the core functionality"
   Step 3: "Add error handling and edge cases"
   Step 4: "Review and optimize the code"
   ```

3. **Leverage Code Generation**
   - Use Composer for boilerplate code
   - Ask for complete examples with proper imports

4. **Documentation Generation**
   - Ask Composer to generate documentation
   - Include examples and usage patterns

## Troubleshooting

### Common Issues

1. **Dependency Issues**
   - Share your `mix.exs` and `pyproject.toml` with Composer
   - Ask for compatible version recommendations

2. **Test Failures**
   - Provide the full test output
   - Ask for specific fixes based on error messages

3. **Integration Problems**
   - Share the relevant component interfaces
   - Ask for proper integration patterns

## Contributing

When contributing to Lux:
1. Follow the guidelines in `guides/contributing.md`
2. Use Composer to help maintain consistent code style
3. Ensure comprehensive test coverage
4. Include proper documentation

## Resources

- [Cursor Documentation](https://cursor.sh/docs)
- [Lux Guides](./guides/)
- [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
- [Phoenix Best Practices](https://hexdocs.pm/phoenix/overview.html) 