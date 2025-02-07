# Contributing to Lux

Thank you for your interest in contributing to Lux! This guide will help you understand how to add new components and contribute to the project.

## Project Structure

Lux follows a modular architecture where components are organized by their type:

```
lib/lux/
├── prisms/         # Prisms for specific functionality
├── lenses/         # Lenses for external integrations
├── beams/          # Beams for workflow orchestration
├── signals/        # Signal definitions
└── schemas/        # Schema definitions
```

## Adding New Components

### Adding a Prism

Prisms should be added under `lib/lux/prisms/` and follow these conventions:
1. One prism per file
2. File name should match the prism's purpose (e.g., `sentiment_analysis_prism.ex`)
3. Module name should be in PascalCase and end with "Prism" (e.g., `Lux.Prisms.SentimentAnalysisPrism`)
4. Include comprehensive documentation and examples
5. Add corresponding tests under `test/lux/prisms/`

Example structure:
```elixir
# lib/lux/prisms/my_feature_prism.ex
defmodule Lux.Prisms.MyFeaturePrism do
  use Lux.Prism,
    name: "My Feature",
    description: "Implements specific functionality",
    input_schema: %{...},
    output_schema: %{...}

  def handler(input, ctx) do
    # Implementation
  end
end

# test/lux/prisms/my_feature_prism_test.exs
defmodule Lux.Prisms.MyFeaturePrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.MyFeaturePrism
  
  test "processes input correctly" do
    # Test implementation
  end
end
```

### Adding a Lens

Lenses should be added under `lib/lux/lenses/` following these guidelines:
1. One lens per file
2. File name should reflect the external service (e.g., `openai_lens.ex`)
3. Module name should end with "Lens" (e.g., `Lux.Lenses.OpenAILens`)
4. Include proper error handling and rate limiting
5. Add tests under `test/lux/lenses/`

Example structure:
```elixir
# lib/lux/lenses/my_service_lens.ex
defmodule Lux.Lenses.MyServiceLens do
  use Lux.Lens,
    name: "My Service",
    description: "Integrates with external service",
    schema: %{...}

  def focus(input, opts) do
    # Implementation
  end
end

# test/lux/lenses/my_service_lens_test.exs
defmodule Lux.Lenses.MyServiceLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.MyServiceLens
  
  test "integrates with service correctly" do
    # Test implementation
  end
end
```

### Adding a Beam

Beams should be added under `lib/lux/beams/` following these conventions:
1. One beam per file
2. File name should describe the workflow (e.g., `user_onboarding_beam.ex`)
3. Module name should end with "Beam" (e.g., `Lux.Beams.UserOnboardingBeam`)
4. Include clear step definitions and error handling
5. Add tests under `test/lux/beams/`

Example structure:
```elixir
# lib/lux/beams/my_workflow_beam.ex
defmodule Lux.Beams.MyWorkflowBeam do
  use Lux.Beam,
    name: "My Workflow",
    description: "Orchestrates a specific workflow"

  def steps do
    sequence do
      step(:validate, MyValidatorPrism, %{...})
      step(:process, MyProcessorPrism, %{...})
      step(:notify, MyNotifierPrism, %{...})
    end
  end
end

# test/lux/beams/my_workflow_beam_test.exs
defmodule Lux.Beams.MyWorkflowBeamTest do
  use ExUnit.Case, async: true
  alias Lux.Beams.MyWorkflowBeam
  
  test "executes workflow correctly" do
    # Test implementation
  end
end
```

## Development Guidelines

1. **Documentation**
   - Add detailed module documentation
   - Include usage examples
   - Document all public functions
   - Add type specs

2. **Testing**
   - Write comprehensive tests
   - Include both unit and integration tests
   - Test error cases
   - Use ExUnit's async tests when possible
   - Mock external services in tests

3. **Code Style**
   - Follow Elixir style guide
   - Use mix format before committing
   - Keep functions small and focused
   - Use meaningful variable names
   - Add type specs for public functions

4. **Python Integration**
   - Add Python dependencies to `priv/python/pyproject.toml`
   - Write Python tests in `priv/python/tests/`
   - Follow Python style guide (Black formatting)
   - Add type hints to Python code
   - Document Python functions

## Pull Request Process

1. Fork the repository
2. Create a feature branch
3. Add your changes following the guidelines above
4. Run all tests (`mix test.suite` and `mix python.test`)
5. Format code (`mix format`)
6. Submit a pull request with:
   - Clear description of changes
   - Any related issues
   - Examples of usage
   - Test coverage report

## Getting Help

- Open an issue for bugs or feature requests
- Join our community chat for questions
- Check existing documentation and guides
- Review existing PRs and issues

Thank you for contributing to Lux! Your efforts help make the project better for everyone. 