# Python Integration in Lux

Lux provides first-class support for Python, allowing you to leverage Python's rich ecosystem of libraries and tools in your agents. This guide explains how to use Python effectively with Lux.

## Writing Python Code

### Using the ~PY Sigil

The `~PY` sigil allows you to write Python code directly in your Elixir files:

```elixir
defmodule MyApp.Prisms.DataAnalysisPrism do
  use Lux.Prism,
    name: "Data Analysis"

  require Lux.Python
  import Lux.Python

  def handler(input, _ctx) do
    result = python variables: %{data: input} do
      ~PY"""
      import numpy as np
      
      # Process input data
      array = np.array(data)
      mean = np.mean(array)
      std = np.std(array)
      
      {
          "mean": float(mean),
          "std": float(std),
          "shape": array.shape
      }
      """
    end

    {:ok, result}
  end
end
```

Key features:
- Multi-line Python code with proper indentation
- Variable binding between Elixir and Python
- Automatic type conversion
- Error handling and timeouts

### Custom Python Modules

You can add your own Python modules under the `priv/python` directory:

```
priv/python/
├── my_module/
│   ├── __init__.py
│   ├── analysis.py
│   └── utils.py
├── another_module.py
└── pyproject.toml
```

These modules can be imported and used in your Lux code:

```elixir
python do
  ~PY"""
  from my_module.analysis import process_data
  from my_module.utils import format_output
  
  result = process_data(input_data)
  formatted = format_output(result)
  """
end
```

## Package Management

### Using Poetry

Lux uses Poetry for Python package management. The `pyproject.toml` file in `priv/python` defines your dependencies:

```toml
[tool.poetry]
name = "lux-python"
version = "0.1.0"
description = "Python support for Lux framework"

[tool.poetry.dependencies]
python = "^3.9"
numpy = "^1.24.0"
pandas = "^2.0.0"
scikit-learn = "^1.2.0"

[tool.poetry.dev-dependencies]
pytest = "^7.0.0"
black = "^23.0.0"
```

To install dependencies:

```bash
cd priv/python
poetry install
```

### Importing Packages

Use `Lux.Python.import_package/1` to dynamically import Python packages:

```elixir
# Import a single package
{:ok, %{"success" => true}} = Lux.Python.import_package("numpy")

# Import multiple packages
for package <- ["pandas", "sklearn", "torch"] do
  {:ok, %{"success" => true}} = Lux.Python.import_package(package)
end
```

## Type Conversion

Lux automatically handles type conversion between Elixir and Python:

| Elixir Type | Python Type |
|-------------|-------------|
| `nil` | `None` |
| `true`/`false` | `True`/`False` |
| Integer | `int` |
| Float | `float` |
| String | `str` |
| Tuple | `tuple` |
| List | `list` |
| Map | `dict` |
| Struct | `dict` |

Example:

```elixir
python variables: %{
  number: 42,
  text: "hello",
  tuple: (1,2),
  list: [1, 2, 3],
  map: %{key: "value"}
} do
  ~PY"""
  # number is an int
  # text is a str
  # tuple is a tuple
  # list is a list
  # map is a dict
  
  {
    "number_type": str(type(number)),
    "text_type": str(type(text)),
    "tuple_type": str(type(tuple)),
    "list_type": str(type(list)),
    "map_type": str(type(map))
  }
  """
end
```

## Error Handling

Python errors are properly captured and converted to Elixir errors:

```elixir
# Handle errors with pattern matching
python do
  ~PY"""
  # This will raise a NameError
  undefined_variable
  """
end |> case do
  {:ok, result} -> IO.inspect(result)
  {:error, error} -> IO.inspect(error)
end

# Or use the bang version to raise errors
python! do
  ~PY"""
  # This will raise a RuntimeError
  raise RuntimeError("Something went wrong")
  """
end
```

## Testing

Test your Python code using the standard Elixir testing tools:

```elixir
defmodule MyApp.Prisms.DataAnalysisPrismTest do
  use UnitCase, async: true
  
  import Lux.Python
  
  test "processes data correctly" do
    result = python variables: %{data: [1, 2, 3, 4, 5]} do
      ~PY"""
      import numpy as np
      np.mean(data)
      """
    end
    
    assert {:ok, 3.0} = result
  end
  
  test "handles errors" do
    assert {:error, error} = python do
      ~PY"""
      undefined_variable
      """
    end
    
    assert error =~ "NameError"
  end
end
```

## Best Practices

1. **Module Organization**
   - Keep related Python code in modules under `priv/python`
   - Use clear module and function names
   - Follow Python style guidelines (PEP 8)

2. **Performance**
   - Batch operations to minimize cross-language calls
   - Use NumPy for numerical operations
   - Consider memory usage with large datasets

3. **Error Handling**
   - Use appropriate error types
   - Provide meaningful error messages
   - Clean up resources in error cases

4. **Testing**
   - Test both success and error cases
   - Verify type conversions
   - Test with realistic data
