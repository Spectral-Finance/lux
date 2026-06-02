defmodule Lux.Native.Type do
  @moduledoc """
  Elixir module wrapping Rust NIFs for advanced type mapping and serialization.

  Provides type mapping between Elixir and Rust types, struct/enum schema
  definition and validation, and Serde-based JSON serialization utilities.

  All operations are delegated to the Rust native library for performance.
  """

  @doc """
  Maps an Elixir type name to its corresponding Rust type.

  ## Examples

      iex> Lux.Native.Type.map_elixir_to_rust("integer")
      "i64"

      iex> Lux.Native.Type.map_elixir_to_rust("binary")
      "String"
  """
  @spec map_elixir_to_rust(String.t()) :: String.t()
  def map_elixir_to_rust(_elixir_type), do: nif_not_loaded()

  @doc """
  Maps a Rust type name to its corresponding Elixir type.

  ## Examples

      iex> Lux.Native.Type.map_rust_to_elixir("i64")
      "integer"

      iex> Lux.Native.Type.map_rust_to_elixir("Vec<Term>")
      "list"
  """
  @spec map_rust_to_elixir(String.t()) :: String.t()
  def map_rust_to_elixir(_rust_type), do: nif_not_loaded()

  @doc """
  Returns the list of standard type mappings between Elixir and Rust.
  """
  @spec get_standard_mappings() :: [map()]
  def get_standard_mappings, do: nif_not_loaded()

  @doc """
  Checks if an Elixir type is compatible with a Rust type.

  ## Examples

      iex> Lux.Native.Type.check_compatibility("integer", "i64")
      true

      iex> Lux.Native.Type.check_compatibility("float", "String")
      false
  """
  @spec check_compatibility(String.t(), String.t()) :: boolean()
  def check_compatibility(_elixir_type, _rust_type), do: nif_not_loaded()

  @doc """
  Validates a type schema definition.

  Returns a map with `:valid` boolean and optional `:errors` list.
  """
  @spec validate_schema(map()) :: map()
  def validate_schema(_schema), do: nif_not_loaded()

  @doc """
  Defines a Rust struct based on field descriptors.
  Returns a map with `:name`, `:schema`, and `:rust_definition`.
  """
  @spec define_struct(String.t(), String.t(), [map()]) :: map()
  def define_struct(_name, _kind, _fields), do: nif_not_loaded()

  @doc """
  Defines a Rust enum based on variant descriptors.
  Returns a map with `:name`, `:schema`, and `:rust_definition`.
  """
  @spec define_enum(String.t(), [map()], String.t()) :: map()
  def define_enum(_name, _variants, _discriminant_type), do: nif_not_loaded()

  @doc """
  Validates and re-encodes a JSON string using serde round-trip.
  """
  @spec serde_validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def serde_validate(_json_str), do: nif_not_loaded()

  @doc """
  Pretty-prints a JSON string using serde.
  """
  @spec serde_pretty_print(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def serde_pretty_print(_json_str), do: nif_not_loaded()

  @doc """
  Compacts a JSON string by removing whitespace using serde.
  """
  @spec serde_compact(String.t()) :: String.t()
  def serde_compact(_json_str), do: nif_not_loaded()

  @doc """
  Sorts keys in a JSON object alphabetically.
  """
  @spec serde_sort_keys(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def serde_sort_keys(_json_str), do: nif_not_loaded()

  @doc """
  Extracts type information from a JSON structure.
  Returns a JSON structure with type annotations.
  """
  @spec serde_extract_types(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def serde_extract_types(_json_str), do: nif_not_loaded()

  @doc """
  Deep merges an overlay JSON object into a base JSON object.
  Nested objects are merged recursively.
  """
  @spec serde_deep_merge(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def serde_deep_merge(_base_json, _overlay_json), do: nif_not_loaded()

  @doc """
  Checks if the Rust native library is available.
  """
  @spec native_loaded?() :: boolean()
  def native_loaded? do
    Lux.Native.loaded?()
  end

  defp nif_not_loaded do
    :erlang.nif_error(:nif_not_loaded)
  end
end
