defmodule Lux.RustType do
  @moduledoc """
  Advanced type system mapping and bidirectional serialization between Elixir and Rust.

  This module provides a comprehensive type conversion layer that enables seamless
  data exchange of complex types (structs, enums, primitives, collections) between
  Elixir and Rust via the NIF boundary.

  ## Design

  Types are represented in a normalised intermediate form (`t:lux_type/0`) that
  maps cleanly to both Elixir terms and Rust values. Conversion is handled via
  `encode/2` (Elixir → intermediate) and `decode/2` (intermediate → Elixir), with
  JSON as the serialisation wire format when crossing the NIF boundary.

  ## Usage

      # Serialize Elixir data for Rust
      {:ok, encoded} = Lux.RustType.encode(%{name: "Lux", version: 1}, :map)

      # Deserialize Rust data back to Elixir
      {:ok, decoded} = Lux.RustType.decode(encoded, :map)

      # Define and use a custom struct type
      schema = Lux.RustType.struct_schema("Point", x: :float, y: :float)
      {:ok, term} = Lux.RustType.decode(%{x: 1.0, y: 2.0}, schema)

  """

  require Logger

  @type primitive :: :integer | :float | :boolean | :string | :atom | :binary | :nil
  @type collection :: {:list, lux_type()} | {:map, lux_type(), lux_type()}
  @type composite :: {:struct, String.t(), keyword(lux_type())} | {:enum, String.t(), [atom()]}
  @type lux_type :: primitive() | collection() | composite() | :any

  # ---------------------------------------------------------------------------
  # Primitive type definitions
  # ---------------------------------------------------------------------------

  @doc """
  Returns all supported primitive Rust types with their Elixir equivalents.
  """
  @spec primitive_types() :: map()
  def primitive_types do
    %{
      # Integer types
      i8: :integer,
      i16: :integer,
      i32: :integer,
      i64: :integer,
      i128: :integer,
      u8: :integer,
      u16: :integer,
      u32: :integer,
      u64: :integer,
      u128: :integer,
      usize: :integer,
      isize: :integer,
      # Float types
      f32: :float,
      f64: :float,
      # Other primitives
      bool: :boolean,
      str: :string,
      string: :string,
      char: :string,
      unit: :nil
    }
  end

  @doc """
  Maps a Rust primitive type atom to its Elixir type atom.
  """
  @spec rust_to_elixir_type(atom()) :: {:ok, lux_type()} | {:error, String.t()}
  def rust_to_elixir_type(rust_type) when is_atom(rust_type) do
    case Map.fetch(primitive_types(), rust_type) do
      {:ok, elixir_type} -> {:ok, elixir_type}
      :error -> {:error, "Unknown Rust type: #{rust_type}"}
    end
  end

  # ---------------------------------------------------------------------------
  # Struct type definitions
  # ---------------------------------------------------------------------------

  @doc """
  Defines a struct type schema suitable for type mapping.

  ## Examples

      schema = Lux.RustType.struct_schema("Point", x: :float, y: :float)
      # => {:struct, "Point", [x: :float, y: :float]}

  """
  @spec struct_schema(String.t(), keyword(lux_type())) :: {:struct, String.t(), keyword()}
  def struct_schema(name, fields) when is_binary(name) and is_list(fields) do
    {:struct, name, fields}
  end

  @doc """
  Defines an enum type schema.

  ## Examples

      schema = Lux.RustType.enum_schema("Direction", [:north, :south, :east, :west])
      # => {:enum, "Direction", [:north, :south, :east, :west]}

  """
  @spec enum_schema(String.t(), [atom()]) :: {:enum, String.t(), [atom()]}
  def enum_schema(name, variants) when is_binary(name) and is_list(variants) do
    {:enum, name, variants}
  end

  # ---------------------------------------------------------------------------
  # Encoding (Elixir → Rust wire format)
  # ---------------------------------------------------------------------------

  @doc """
  Encodes an Elixir value to a JSON-serialisable form for Rust.

  Supported types: `:integer`, `:float`, `:boolean`, `:string`, `:atom`,
  `:binary`, `:nil`, `{:list, inner_type}`, `{:map, key_type, value_type}`,
  `{:struct, name, fields}`, `{:enum, name, variants}`, `:any`.

  ## Examples

      {:ok, 42} = Lux.RustType.encode(42, :integer)
      {:ok, "hello"} = Lux.RustType.encode(:hello, :atom)
      {:ok, %{"x" => 1.0}} = Lux.RustType.encode(%{x: 1.0}, {:struct, "Point", [x: :float]})

  """
  @spec encode(term(), lux_type()) :: {:ok, term()} | {:error, String.t()}
  def encode(value, :any), do: {:ok, value}
  def encode(nil, :nil), do: {:ok, nil}
  def encode(value, :nil) when not is_nil(value), do: {:error, "Expected nil, got: #{inspect(value)}"}

  def encode(value, :integer) when is_integer(value), do: {:ok, value}
  def encode(value, :float) when is_float(value), do: {:ok, value}
  def encode(value, :float) when is_integer(value), do: {:ok, value / 1}
  def encode(value, :boolean) when is_boolean(value), do: {:ok, value}
  def encode(value, :string) when is_binary(value), do: {:ok, value}
  def encode(value, :binary) when is_binary(value), do: {:ok, Base.encode64(value)}
  def encode(value, :atom) when is_atom(value), do: {:ok, to_string(value)}
  def encode(value, :atom) when is_binary(value), do: {:ok, value}

  def encode(values, {:list, inner}) when is_list(values) do
    result =
      Enum.reduce_while(values, [], fn v, acc ->
        case encode(v, inner) do
          {:ok, encoded} -> {:cont, [encoded | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      list -> {:ok, Enum.reverse(list)}
    end
  end

  def encode(map, {:map, _key_type, value_type}) when is_map(map) do
    result =
      Enum.reduce_while(map, %{}, fn {k, v}, acc ->
        key = to_string(k)

        case encode(v, value_type) do
          {:ok, encoded} -> {:cont, Map.put(acc, key, encoded)}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      map_result -> {:ok, map_result}
    end
  end

  def encode(value, {:struct, _name, fields}) when is_map(value) do
    result =
      Enum.reduce_while(fields, %{}, fn {field, field_type}, acc ->
        field_value = Map.get(value, field) || Map.get(value, to_string(field))

        case encode(field_value, field_type) do
          {:ok, encoded} ->
            {:cont, Map.put(acc, to_string(field), encoded)}

          {:error, reason} ->
            {:halt, {:error, "Struct field #{field}: #{reason}"}}
        end
      end)

    case result do
      {:error, _} = err -> err
      struct_map -> {:ok, struct_map}
    end
  end

  def encode(value, {:enum, _name, variants}) when is_atom(value) do
    if value in variants do
      {:ok, to_string(value)}
    else
      {:error, "Value #{inspect(value)} is not a valid enum variant in #{inspect(variants)}"}
    end
  end

  def encode(value, {:enum, _name, variants}) when is_binary(value) do
    atom = String.to_existing_atom(value)

    if atom in variants do
      {:ok, value}
    else
      {:error, "Value #{inspect(value)} is not a valid enum variant"}
    end
  rescue
    ArgumentError ->
      {:error, "Value #{inspect(value)} is not a known atom"}
  end

  def encode(value, type) do
    {:error, "Cannot encode #{inspect(value)} as #{inspect(type)}"}
  end

  # ---------------------------------------------------------------------------
  # Decoding (Rust wire format → Elixir)
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a value from Rust's wire representation back into an Elixir term.

  ## Examples

      {:ok, 42} = Lux.RustType.decode(42, :integer)
      {:ok, :hello} = Lux.RustType.decode("hello", :atom)
      {:ok, %{x: 1.0, y: 2.0}} = Lux.RustType.decode(%{"x" => 1.0, "y" => 2.0}, {:struct, "Point", [x: :float, y: :float]})

  """
  @spec decode(term(), lux_type()) :: {:ok, term()} | {:error, String.t()}
  def decode(value, :any), do: {:ok, value}
  def decode(nil, :nil), do: {:ok, nil}
  def decode(value, :integer) when is_integer(value), do: {:ok, value}
  def decode(value, :float) when is_float(value), do: {:ok, value}
  def decode(value, :float) when is_integer(value), do: {:ok, value / 1}
  def decode(value, :boolean) when is_boolean(value), do: {:ok, value}
  def decode(value, :string) when is_binary(value), do: {:ok, value}

  def decode(value, :binary) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, "Invalid base64 binary: #{inspect(value)}"}
    end
  end

  def decode(value, :atom) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> {:ok, String.to_atom(value)}
  end

  def decode(value, :atom) when is_atom(value), do: {:ok, value}

  def decode(values, {:list, inner}) when is_list(values) do
    result =
      Enum.reduce_while(values, [], fn v, acc ->
        case decode(v, inner) do
          {:ok, decoded} -> {:cont, [decoded | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      list -> {:ok, Enum.reverse(list)}
    end
  end

  def decode(map, {:map, _key_type, value_type}) when is_map(map) do
    result =
      Enum.reduce_while(map, %{}, fn {k, v}, acc ->
        case decode(v, value_type) do
          {:ok, decoded} -> {:cont, Map.put(acc, k, decoded)}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      map_result -> {:ok, map_result}
    end
  end

  def decode(value, {:struct, _name, fields}) when is_map(value) do
    result =
      Enum.reduce_while(fields, %{}, fn {field, field_type}, acc ->
        field_value = Map.get(value, to_string(field)) || Map.get(value, field)

        case decode(field_value, field_type) do
          {:ok, decoded} ->
            {:cont, Map.put(acc, field, decoded)}

          {:error, reason} ->
            {:halt, {:error, "Struct field #{field}: #{reason}"}}
        end
      end)

    case result do
      {:error, _} = err -> err
      struct_map -> {:ok, struct_map}
    end
  end

  def decode(value, {:enum, _name, variants}) when is_binary(value) do
    atom =
      try do
        String.to_existing_atom(value)
      rescue
        ArgumentError -> String.to_atom(value)
      end

    if atom in variants do
      {:ok, atom}
    else
      {:error, "Value #{inspect(value)} is not a valid variant in #{inspect(variants)}"}
    end
  end

  def decode(value, {:enum, _name, variants}) when is_atom(value) do
    if value in variants do
      {:ok, value}
    else
      {:error, "Value #{inspect(value)} is not a valid variant in #{inspect(variants)}"}
    end
  end

  def decode(value, type) do
    {:error, "Cannot decode #{inspect(value)} as #{inspect(type)}"}
  end

  # ---------------------------------------------------------------------------
  # Bidirectional JSON serialization
  # ---------------------------------------------------------------------------

  @doc """
  Serializes any Elixir term to a JSON string, optionally encoding with a type schema.

  ## Examples

      {:ok, json} = Lux.RustType.to_json(%{name: "Lux", count: 42})
      {:ok, json} = Lux.RustType.to_json(%{x: 1.0}, {:struct, "Point", [x: :float]})

  """
  @spec to_json(term(), lux_type()) :: {:ok, String.t()} | {:error, String.t()}
  def to_json(value, type \\ :any) do
    with {:ok, encoded} <- encode(value, type),
         {:ok, json} <- Jason.encode(encoded) do
      {:ok, json}
    end
  end

  @doc """
  Deserializes a JSON string to an Elixir term, optionally decoding with a type schema.

  ## Examples

      {:ok, %{"name" => "Lux"}} = Lux.RustType.from_json(~s({"name": "Lux"}))
      {:ok, %{x: 1.0}} = Lux.RustType.from_json(~s({"x": 1.0}), {:struct, "Point", [x: :float]})

  """
  @spec from_json(String.t(), lux_type()) :: {:ok, term()} | {:error, String.t()}
  def from_json(json, type \\ :any) when is_binary(json) do
    with {:ok, parsed} <- Jason.decode(json) do
      decode(parsed, type)
    end
  end

  # ---------------------------------------------------------------------------
  # Type validation
  # ---------------------------------------------------------------------------

  @doc """
  Validates that `value` conforms to `type` without converting it.
  Returns `:ok` or `{:error, reason}`.

  ## Examples

      :ok = Lux.RustType.validate(42, :integer)
      {:error, _} = Lux.RustType.validate("hello", :integer)

  """
  @spec validate(term(), lux_type()) :: :ok | {:error, String.t()}
  def validate(value, type) do
    case encode(value, type) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns `true` if `value` conforms to `type`.
  """
  @spec valid?(term(), lux_type()) :: boolean()
  def valid?(value, type) do
    match?(:ok, validate(value, type))
  end

  # ---------------------------------------------------------------------------
  # Type inspection utilities
  # ---------------------------------------------------------------------------

  @doc """
  Infers the `lux_type` of an Elixir value at runtime.

  ## Examples

      :integer = Lux.RustType.infer(42)
      :string = Lux.RustType.infer("hello")
      {:list, :integer} = Lux.RustType.infer([1, 2, 3])

  """
  @spec infer(term()) :: lux_type()
  def infer(value) when is_nil(value), do: :nil
  def infer(value) when is_integer(value), do: :integer
  def infer(value) when is_float(value), do: :float
  def infer(value) when is_boolean(value), do: :boolean
  def infer(value) when is_binary(value), do: :string
  def infer(value) when is_atom(value), do: :atom

  def infer([]) do
    {:list, :any}
  end

  def infer([head | _] = list) when is_list(list) do
    {:list, infer(head)}
  end

  def infer(map) when is_map(map) do
    values = Map.values(map)
    value_type = if values == [], do: :any, else: infer(hd(values))
    {:map, :string, value_type}
  end

  def infer(_), do: :any

  # ---------------------------------------------------------------------------
  # Custom type registry
  # ---------------------------------------------------------------------------

  @doc """
  Registers a named type schema in the process dictionary for reuse.

  ## Examples

      Lux.RustType.register_type("Point", Lux.RustType.struct_schema("Point", x: :float, y: :float))
      {:ok, schema} = Lux.RustType.lookup_type("Point")

  """
  @spec register_type(String.t(), lux_type()) :: :ok
  def register_type(name, schema) when is_binary(name) do
    existing = Process.get(:lux_rust_type_registry, %{})
    Process.put(:lux_rust_type_registry, Map.put(existing, name, schema))
    :ok
  end

  @doc """
  Looks up a previously registered type schema by name.
  """
  @spec lookup_type(String.t()) :: {:ok, lux_type()} | {:error, String.t()}
  def lookup_type(name) when is_binary(name) do
    registry = Process.get(:lux_rust_type_registry, %{})

    case Map.fetch(registry, name) do
      {:ok, schema} -> {:ok, schema}
      :error -> {:error, "Type not registered: #{name}"}
    end
  end
end
