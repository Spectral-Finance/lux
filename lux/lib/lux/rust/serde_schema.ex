defmodule Lux.Rust.SerdeSchema do
  @moduledoc """
  Schema-first Rust type mapping and Serde serialization.

  This module provides a pure-Elixir API that wraps the native Rust NIFs
  in `Lux.Native.Type` with idiomatic Elixir result tuples and conversions.

  It supports:
  - Primitive type mapping between Elixir and Rust
  - Struct schema definition
  - Enum schema definition
  - JSON value encoding/decoding
  - Type manifest export
  """

  alias Lux.Native.Type, as: NT

  @type type_mapping :: %{
          elixir_type: String.t(),
          rust_type: String.t(),
          serde_format: String.t(),
          conversion_hint: String.t()
        }

  @doc """
  Returns all standard type mappings between Elixir and Rust.
  """
  @spec type_mappings() :: [type_mapping()]
  def type_mappings do
    NT.get_standard_mappings()
  end

  @doc """
  Maps an Elixir type atom/string to the equivalent Rust type.
  """
  @spec elixir_type_to_rust(atom() | String.t()) :: String.t()
  def elixir_type_to_rust(type) when is_atom(type), do: type |> to_string() |> elixir_type_to_rust()
  def elixir_type_to_rust(type), do: NT.map_elixir_to_rust(type)

  @doc """
  Maps a Rust type string to the equivalent Elixir type.
  """
  @spec rust_type_to_elixir(String.t()) :: String.t()
  def rust_type_to_elixir(type), do: NT.map_rust_to_elixir(type)

  @doc """
  Checks type compatibility between Elixir and Rust.
  """
  @spec compatible?(String.t(), String.t()) :: boolean()
  def compatible?(elixir_type, rust_type), do: NT.check_compatibility(elixir_type, rust_type)

  @doc """
  Defines a Rust struct from Elixir field descriptors.

  Each field is a map with:
  - `:name` — field name
  - `:rust_type` — Rust type (e.g., "i64", "String")
  - `:is_optional` — whether the field is Option<T>
  - `:default_value` — optional default
  - `:validators` — list of validator strings

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec define_struct(String.t(), [map()]) :: {:ok, map()} | {:error, String.t()}
  def define_struct(name, fields) when is_list(fields) do
    json =
      fields
      |> Enum.map(&Map.new/1)
      |> Jason.encode!()

    case NT.define_struct(name, "struct", json) do
      result when is_map(result) -> {:ok, result}
      error -> {:error, "#{inspect(error)}"}
    end
  rescue
    e in RuntimeError -> {:error, Exception.message(e)}
  end

  @doc """
  Defines a Rust enum from Elixir variant descriptors.

  Each variant is a map with:
  - `:name` — variant name
  - `:value` — discriminant value
  - `:has_payload` — whether variant carries data
  - `:payload_type` — Rust type of payload if any

  Returns `{:ok, result}` or `{:error, reason}`.
  """
  @spec define_enum(String.t(), [map()], String.t()) :: {:ok, map()} | {:error, String.t()}
  def define_enum(name, variants, discriminant_type \\ "i64") when is_list(variants) do
    json =
      variants
      |> Enum.map(&Map.new/1)
      |> Jason.encode!()

    case NT.define_enum(name, json, discriminant_type) do
      result when is_map(result) -> {:ok, result}
      error -> {:error, "#{inspect(error)}"}
    end
  rescue
    e in RuntimeError -> {:error, Exception.message(e)}
  end

  @doc """
  Validates a JSON string by round-tripping through serde.
  Returns `{:ok, kind}` where kind is the JSON value type, or `{:error, reason}`.
  """
  @spec validate_json(String.t()) :: {:ok, map()} | {:error, String.t()}
  def validate_json(json) do
    case NT.serde_validate(json) do
      result when is_binary(result) ->
        case Jason.decode(result) do
          {:ok, %{"valid" => true} = map} -> {:ok, map}
          {:ok, %{"valid" => false, "error" => error}} -> {:error, error}
          _ -> {:error, "unexpected response"}
        end
      error -> {:error, "#{inspect(error)}"}
    end
  end

  @doc """
  Pretty-prints a JSON string.
  """
  @spec pretty_print_json(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def pretty_print_json(json) do
    case NT.serde_pretty_print(json) do
      result when is_binary(result) -> {:ok, result}
      error -> {:error, "#{inspect(error)}"}
    end
  end

  @doc """
  Compacts a JSON string by removing extraneous whitespace.
  """
  @spec compact_json(String.t()) :: String.t()
  def compact_json(json), do: NT.serde_compact(json)

  @doc """
  Sorts JSON object keys alphabetically.
  """
  @spec sort_json_keys(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def sort_json_keys(json) do
    case NT.serde_sort_keys(json) do
      result when is_binary(result) -> {:ok, result}
      error -> {:error, "#{inspect(error)}"}
    end
  end

  @doc """
  Extracts type annotations from a JSON value.
  Returns a JSON structure describing the types found.
  """
  @spec extract_types(String.t()) :: {:ok, map()} | {:error, String.t()}
  def extract_types(json) do
    case NT.serde_extract_types(json) do
      result when is_binary(result) ->
        case Jason.decode(result) do
          {:ok, types} -> {:ok, types}
          _ -> {:error, "failed to decode type extraction result"}
        end
      error -> {:error, "#{inspect(error)}"}
    end
  end

  @doc """
  Deep merges two JSON objects, with overlay taking precedence.
  """
  @spec deep_merge_json(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def deep_merge_json(base_json, overlay_json) do
    case NT.serde_deep_merge(base_json, overlay_json) do
      result when is_binary(result) -> {:ok, result}
      error -> {:error, "#{inspect(error)}"}
    end
  end

  @doc """
  Generates a type manifest that maps all Lux Elixir types to Rust.
  """
  @spec type_manifest() :: %{String.t() => String.t()}
  def type_manifest do
    mappings = type_mappings()
    Map.new(mappings, fn %{elixir_type: e, rust_type: r} -> {e, r} end)
  end
end
