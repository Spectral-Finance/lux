# Lux Python Components

This directory contains the Python components of the Lux framework. It's structured as a proper Python package with dependency management via Poetry.

## Development Setup

1. Install Poetry and (if not already installed):
   ```bash
   curl -sSL https://install.python-poetry.org | python3 -
   poetry self add poetry-plugin-shell
   ```

2. Activate the virtual environment:
   ```bash
   poetry shell --directory=priv/python
   ```

3. Install dependencies:
   ```bash
   poetry install --directory=priv/python
   ```

## Running Tests

```bash
# Run all tests with coverage
poetry run pytest

# Run specific test file
poetry run pytest tests/test_eval.py

# Run tests with specific marker
poetry run pytest -m "not slow"
```

## Code Style

We use Black for code formatting and isort for import sorting:

```bash
# Format code
poetry run black .

# Sort imports
poetry run isort .

# Type checking
poetry run mypy lux
```

## Adding Dependencies

To add a new dependency:
```bash
poetry add package-name

# For dev dependencies (tests, formatting, etc.)
poetry add --group dev package-name
```

## Project Structure

```
priv/python/
├── lux/                    # Main package directory
│   ├── __init__.py
│   ├── eval.py            # Python evaluation module
│   └── safe_atoms.py      # Safe atoms definition
├── tests/                  # Test directory
│   ├── __init__.py
│   ├── conftest.py        # pytest configuration
│   └── test_*.py          # Test files
├── pyproject.toml         # Poetry configuration
└── README.md             # This file
```

## Integration with Elixir

This Python package is used by the Lux Elixir framework through erlport. The Python path in your Elixir configuration should point to this directory:

```elixir
# config/config.exs
config :venomous, :snake_manager, %{
  python_opts: [
    module_paths: ["priv/python"],
    # ...
  ]
}
``` 