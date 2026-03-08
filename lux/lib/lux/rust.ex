defmodule Lux.Rust do
  @moduledoc """
  Rust integration utilities for Lux.

  Provides helper functions for working with Rust NIFs, type conversion
  between Elixir and Rust types, and error handling.

  ## Type Mapping

  | Elixir          | Rust             | JSON type   |
  |-----------------|------------------|-------------|
  | `String.t()`    | `String`         | `"string"`  |
  | `integer()`     | `i64`/`u64`      | `"integer"` |
  | `float()`       | `f64`            | `"float"`   |
  | `boolean()`     | `bool`           | `"boolean"` |
  | `nil`           | `None`/`null`    | `"null"`    |
  | `list()`        | `Vec<T>`         | `"array"`   |
  | `map()`         | `HashMap<K,V>`   | `"object"`  |

  ## Error Handling

  Rust errors are propagated as `{:error, reason}` tuples where `reason`
  is a human-readable string describing the error.
  """

  alias Lux.Native

  @doc """
  Convert an Elixir term to JSON, send through Rust for validation,
  and convert back. Useful for verifying serialization correctness.

      iex> Lux.Rust.roundtrip(%{key: "value"})
      {:ok, %{"key" => "value"}}
  """
  @spec roundtrip(term()) :: {:ok, term()} | {:error, String.t()}
  def roundtrip(term) do
    with {:ok, json} <- Jason.encode(term),
         result when is_binary(result) <- Native.json_roundtrip(json),
         {:ok, decoded} <- Jason.decode(result) do
      {:ok, decoded}
    else
      {:error, reason} -> {:error, to_string(reason)}
      error -> {:error, "Unexpected: #{inspect(error)}"}
    end
  end

  @doc """
  Validate that a term matches an expected JSON type.

      iex> Lux.Rust.validate("hello", "string")
      :ok

      iex> Lux.Rust.validate(42, "string")
      {:error, "Type mismatch: expected string, got integer"}
  """
  @spec validate(term(), String.t()) :: :ok | {:error, String.t()}
  def validate(term, type_name) do
    with {:ok, json} <- Jason.encode(term) do
      case Native.validate_json(json, type_name) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Hash a string with SHA-256 using the Rust implementation.

      iex> Lux.Rust.sha256("hello")
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  """
  @spec sha256(String.t()) :: String.t()
  def sha256(data), do: Native.sha256_hex(data)

  @doc """
  Check if the Rust NIF is loaded and functional.
  """
  @spec available?() :: boolean()
  def available? do
    try do
      case Native.json_roundtrip("null") do
        "null" -> true
        _ -> false
      end
    rescue
      _ -> false
    end
  end
end
