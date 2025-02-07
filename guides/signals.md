# Signals Guide

Signals are the fundamental units of communication in Lux. They provide a type-safe, schema-validated way for components to exchange information.

## Overview

A Signal consists of:
- A unique identifier
- A schema identifier that defines its structure
- Content that conforms to the schema
- Metadata about the signal's context and processing

## Creating a Signal Schema

Signal schemas define the structure and validation rules for signals:

```elixir
defmodule MyApp.Schemas.TaskSchema do
  use Lux.SignalSchema,
    name: "task",
    version: "1.0.0",
    description: "Represents a task assignment",
    schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        due_date: %{type: :string, format: "date-time"},
        assignee: %{type: :string},
        tags: %{type: :array, items: %{type: :string}}
      },
      required: ["title", "priority", "assignee"]
    },
    tags: ["task", "workflow"],
    compatibility: :full,
    format: :json
end
```

## Creating a Signal

Signals are created by modules that use the `Lux.Signal` behaviour:

```elixir
defmodule MyApp.Signals.Task do
  use Lux.Signal,
    schema_id: MyApp.Schemas.TaskSchema
end
```

## Signal Validation

Lux uses JSON Schema (Draft 4) for validating signal payloads. This provides a robust, standardized way to ensure your signals conform to their expected structure.

### Basic Types

The following basic types are supported:

```elixir
# Null validation
defmodule NullSchema do
  use Lux.SignalSchema,
    schema: %{type: :null}
end

# Boolean validation
defmodule BooleanSchema do
  use Lux.SignalSchema,
    schema: %{type: :boolean}
end

# Integer validation
defmodule IntegerSchema do
  use Lux.SignalSchema,
    schema: %{type: :integer}
end

# String validation
defmodule StringSchema do
  use Lux.SignalSchema,
    schema: %{type: :string}
end

# Array validation
defmodule ArraySchema do
  use Lux.SignalSchema,
    schema: %{
      type: :array,
      items: %{type: :string}  # Validates each array item
    }
end
```

### Object Validation

Objects can have nested properties and required fields:

```elixir
defmodule ComplexObjectSchema do
  use Lux.SignalSchema,
    schema: %{
      type: :object,
      properties: %{
        name: %{type: :string},
        age: %{type: :integer},
        tags: %{
          type: :array,
          items: %{type: :string}
        },
        metadata: %{
          type: :object,
          properties: %{
            created_at: %{type: :string, format: "date-time"},
            priority: %{type: :string, enum: ["low", "medium", "high"]}
          },
          required: ["created_at"]
        }
      },
      required: ["name", "age"]  # Top-level required fields
    }
end
```

### Format Validation

Lux supports the following formats out of the box:
- `date-time`: ISO 8601 dates (e.g., "2024-03-21T17:32:28Z")
- `email`: Email addresses
- `hostname`: Valid hostnames
- `ipv4`: IPv4 addresses
- `ipv6`: IPv6 addresses

Example:

```elixir
defmodule UserSchema do
  use Lux.SignalSchema,
    schema: %{
      type: :object,
      properties: %{
        email: %{type: :string, format: "email"},
        last_login: %{type: :string, format: "date-time"},
        server: %{type: :string, format: "hostname"}
      }
    }
end
```

### Custom Format Validation

You can add custom format validators in your configuration:

```elixir
# In config/config.exs
config :ex_json_schema,
  :custom_format_validator,
  fn
    # Validate a custom UUID format
    "uuid", value ->
      case UUID.info(value) do
        {:ok, _} -> true
        {:error, _} -> false
      end
    
    # Return true for unknown formats (as per JSON Schema spec)
    _, _ -> true
  end
```

<!-- TODO: Add support for runtime custom formatters via resolve callbacks at schema definition. ref: https://github.com/jonasschmidt/ex_json_schema?tab=readme-ov-file#custom-formats -->

### Validation Errors

When validation fails, you get detailed error messages:

```elixir
# Missing required field
{:error, [{"Required property name was not present.", "#"}]}

# Type mismatch
{:error, [{"Type mismatch. Expected Integer but got String.", "#/age"}]}

# Invalid format
{:error, [{"Format validation failed.", "#/email"}]}

# Invalid enum value
{:error, [{"Value not allowed.", "#/metadata/priority"}]}
```

### Best Practices for Schema Validation

1. **Type Safety**
   - Always specify types for properties
   - Use appropriate types (e.g., `:integer` vs `:number`)
   - Consider using enums for constrained string values

2. **Required Fields**
   - Mark essential fields as required
   - Consider the impact on backward compatibility
   - Document why fields are required

3. **Nested Validation**
   - Break down complex objects into logical groups
   - Use nested required fields for sub-objects
   - Keep nesting depth reasonable

4. **Format Validation**
   - Use built-in formats when possible
   - Create custom formats for domain-specific values
   - Document format requirements

5. **Error Handling**
   - Handle validation errors gracefully
   - Provide clear error messages
   - Consider aggregating multiple validation errors

6. **Testing**
   - Test both valid and invalid cases
   - Test edge cases and boundary values
   - Test format validation thoroughly

```elixir
defmodule MyApp.Schemas.TaskSchemaTest do
  use ExUnit.Case, async: true

  test "validates required fields" do
    assert {:error, _} = TaskSchema.validate(%Lux.Signal{payload: %{}})
    assert {:error, _} = TaskSchema.validate(%Lux.Signal{payload: %{title: "Test"}})
    assert {:ok, _} = TaskSchema.validate(
      %Lux.Signal{payload: %{title: "Test", priority: "high", assignee: "alice"}}
    )
  end

  test "validates field types" do
    assert {:error, _} = TaskSchema.validate(
      %Lux.Signal{payload: %{title: 123, priority: "high", assignee: "alice"}}
    )
  end

  test "validates enums" do
    assert {:error, _} = TaskSchema.validate(
      %Lux.Signal{payload: %{title: "Test", priority: "invalid", assignee: "alice"}}
    )
  end
end
```

## Using Signals

Signals can be created and used in various ways:

```elixir
# Create a new task signal
{:ok, signal} = MyApp.Signals.Task.new(%{
  title: "Review PR",
  priority: "high",
  assignee: "alice",
  tags: ["github", "code-review"]
})

# Access signal properties
signal.id          # Unique identifier
signal.schema_id   # Schema identifier
signal.payload     # Validated payload
signal.metadata    # Signal metadata
```

## Schema Evolution

Lux supports schema evolution through versioning and compatibility levels:

- `:full` - New schema must be fully compatible with old schema
- `:backward` - New schema can read old data
- `:forward` - Old schema can read new data
- `:none` - No compatibility guarantees

Example of schema evolution:

```elixir
defmodule MyApp.Schemas.TaskSchemaV2 do
  use Lux.SignalSchema,
    name: "task",
    version: "2.0.0",
    description: "Task assignment with status tracking",
    schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        description: %{type: :string},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        due_date: %{type: :string, format: "date-time"},
        assignee: %{type: :string},
        tags: %{type: :array, items: %{type: :string}},
        status: %{type: :string, enum: ["pending", "in_progress", "completed"]},
        progress: %{type: :integer, minimum: 0, maximum: 100}
      },
      required: ["title", "priority", "assignee", "status"]
    },
    compatibility: :backward,
    reference: "v1: MyApp.Schemas.TaskSchema"
end
```

## Best Practices

1. **Schema Design**
   - Use semantic versioning for schemas
   - Document schema changes
   - Consider backward compatibility
   - Use appropriate compatibility levels

2. **Validation**
   - Validate business rules in `validate/1`
   - Keep validations focused and specific
   - Return clear error messages

4. **Testing**
   - Test schema validation
   - Test business rule validation
   - Test compatibility between versions

Example test:
```elixir
defmodule MyApp.Signals.TaskTest do
  use ExUnit.Case, async: true

  describe "new/1" do
    test "creates valid task signal" do
      {:ok, signal} = MyApp.Signals.Task.new(%{
        title: "Test Task",
        priority: "high",
        assignee: "bob"
      })

      assert signal.payload.title == "Test Task"
      assert signal.payload.priority == "high"
      assert signal.payload.assignee == "bob"
    end

    test "validates title presence" do
      assert {:error, "Title cannot be empty"} = 
        MyApp.Signals.Task.new(%{priority: "high", assignee: "bob"})
    end
  end
end
```

## Advanced Topics

### Schema Documentation
Schemas can include rich documentation:

```elixir
defmodule MyApp.Schemas.DocumentedTaskSchema do
  use Lux.SignalSchema,
    name: "documented_task",
    version: "1.0.0",
    description: """
    Represents a task assignment in the system.
    Tasks are the basic unit of work assignment and tracking.
    """,
    schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Short title describing the task",
          examples: ["Review PR #123", "Deploy to production"]
        },
        priority: %{
          type: :string,
          enum: ["low", "medium", "high"],
          description: "Task priority level",
          default: "medium"
        }
      }
    },
    tags: ["task", "workflow"],
    reference: "https://example.com/docs/task-schema"
end
```

### Custom Validation Rules

You can implement complex validation rules:

```elixir
defmodule MyApp.Signals.ComplexTask do
  use Lux.Signal,
    schema: MyApp.Schemas.TaskSchema

  def validate(%{due_date: due_date} = content) do
    with {:ok, parsed_date} <- DateTime.from_iso8601(due_date),
         :ok <- validate_future_date(parsed_date),
         :ok <- validate_working_hours(parsed_date) do
      {:ok, content}
    end
  end

  defp validate_future_date(date) do
    if DateTime.compare(date, DateTime.utc_now()) == :gt do
      :ok
    else
      {:error, "Due date must be in the future"}
    end
  end

  defp validate_working_hours(date) do
    if date.hour >= 9 and date.hour <= 17 do
      :ok
    else
      {:error, "Due date must be during working hours (9-17)"}
    end
  end
end
```

### Signal Metadata

Metadata provides context about the signal's creation and processing:

```elixir
defmodule MyApp.Signals.MetadataTask do
  use Lux.Signal,
    schema: MyApp.Schemas.TaskSchema
end
``` 