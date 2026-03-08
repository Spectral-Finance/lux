defmodule Lux.Rust.TypeSystem do
  @moduledoc """
  Advanced type system for bidirectional Elixir ↔ Rust type conversion.

  Supports struct definitions, enum variants, optional types, tuples,
  and schema-based validation via Rust NIFs.

  ## Type Mapping

  | Elixir Term              | LuxType Tag  |
  |--------------------------|--------------|
  | `"hello"`                | `string`     |
  | `42`                     | `integer`    |
  | `3.14`                   | `float`      |
  | `true/false`             | `boolean`    |
  | `nil`                    | `null`       |
  | `[1, 2, 3]`             | `list`       |
  | `%{key: val}`            | `map`        |
  | `%MyStruct{}`            | `struct`     |
  | `{:variant, data}`       | `enum`       |
  | `{a, b}`                 | `tuple`      |
  | `<<binary>>`             | `binary`     |
  """

  alias Lux.Native

  @doc """
  Convert an Elixir term to a tagged LuxType JSON, process through Rust, and back.

      iex> Lux.Rust.TypeSystem.convert(%{name: "Alice", age: 30})
      {:ok, %{"type" => "map", "entries" => ...}}
  """
  @spec convert(term()) :: {:ok, map()} | {:error, String.t()}
  def convert(term) do
    with {:ok, json} <- Jason.encode(term),
         typed <- Native.to_lux_type(json) do
      Jason.decode(typed)
    end
  end

  @doc """
  Round-trip: Elixir → LuxType → plain value

      iex> Lux.Rust.TypeSystem.roundtrip(%{name: "Alice"})
      {:ok, %{"name" => "Alice"}}
  """
  @spec roundtrip(term()) :: {:ok, term()} | {:error, String.t()}
  def roundtrip(term) do
    with {:ok, json} <- Jason.encode(term),
         typed <- Native.to_lux_type(json),
         plain <- Native.from_lux_type(typed) do
      Jason.decode(plain)
    end
  end

  @doc """
  Validate a term against a schema.

  Schema format:
      %{
        "name" => "User",
        "type" => %{"kind" => "struct", "fields" => %{
          "name" => %{"name" => "name", "type" => %{"kind" => "primitive", "name" => "string"}},
          "age" => %{"name" => "age", "type" => %{"kind" => "primitive", "name" => "integer"}}
        }},
        "required" => ["name", "age"]
      }
  """
  @spec validate(term(), map()) :: :ok | {:error, String.t()}
  def validate(term, schema) when is_map(schema) do
    with {:ok, json} <- Jason.encode(term),
         {:ok, schema_json} <- Jason.encode(schema) do
      case Native.validate_schema(json, schema_json) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Define a struct schema.

      Lux.Rust.TypeSystem.define_struct("User", %{
        "name" => "string",
        "age" => "integer",
        "email" => "string"
      }, required: ["name", "age"])
  """
  @spec define_struct(String.t(), map(), keyword()) :: map()
  def define_struct(name, fields, opts \\ []) do
    required = Keyword.get(opts, :required, [])
    desc = Keyword.get(opts, :description, "")

    field_schemas = Map.new(fields, fn {k, type_name} ->
      {k, %{
        "name" => k,
        "type" => %{"kind" => "primitive", "name" => type_name},
        "required" => [],
        "description" => ""
      }}
    end)

    %{
      "name" => name,
      "type" => %{"kind" => "struct", "fields" => field_schemas},
      "required" => required,
      "description" => desc
    }
  end

  @doc """
  Define an enum schema.

      Lux.Rust.TypeSystem.define_enum("Status", [
        {"active", nil},
        {"error", "string"}
      ])
  """
  @spec define_enum(String.t(), [{String.t(), String.t() | nil}]) :: map()
  def define_enum(name, variants) do
    variant_schemas = Enum.map(variants, fn
      {vname, nil} -> %{"name" => vname}
      {vname, type_name} -> %{"name" => vname, "data" => %{
        "name" => "data", "type" => %{"kind" => "primitive", "name" => type_name},
        "required" => [], "description" => ""
      }}
    end)

    %{
      "name" => name,
      "type" => %{"kind" => "enum", "variants" => variant_schemas},
      "required" => [],
      "description" => ""
    }
  end

  @doc """
  Define a list schema.

      Lux.Rust.TypeSystem.define_list("string")
  """
  @spec define_list(String.t()) :: map()
  def define_list(item_type) do
    %{
      "name" => "list",
      "type" => %{"kind" => "list", "items" => %{
        "name" => "item", "type" => %{"kind" => "primitive", "name" => item_type},
        "required" => [], "description" => ""
      }},
      "required" => [],
      "description" => ""
    }
  end
end
