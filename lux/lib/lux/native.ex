defmodule Lux.Native do
  @moduledoc """
  Native Rust FFI bindings for high-performance operations.

  Provides NIF (Native Implemented Functions) bindings to the Rust
  core for computationally intensive operations including:
  - Cryptographic hashing (SHA-256, Keccak-256)
  - Hex encoding/decoding
  - JSON parsing
  - Arithmetic operations
  - Type introspection
  - Map/list manipulation

  ## Setup

  Add `rustler` to your mix.exs:

      {:rustler, "~> 0.34"}

  Then compile the native library:

      cd priv/rust && cargo build --release

  ## Usage

      Lux.Native.hash_sha256("hello world")
      Lux.Native.add(1, 2)
      Lux.Native.hex_encode("hello")
  """

  @doc """
  Adds two integers.
  """
  @spec add(integer(), integer()) :: integer()
  def add(_a, _b), do: nif_not_loaded()

  @doc """
  Multiplies two integers.
  """
  @spec multiply(integer(), integer()) :: integer()
  def multiply(_a, _b), do: nif_not_loaded()

  @doc """
  Computes SHA-256 hash of a string.
  Returns hex-encoded hash.
  """
  @spec hash_sha256(String.t()) :: String.t()
  def hash_sha256(_data), do: nif_not_loaded()

  @doc """
  Computes Keccak-256 hash of a string.
  Returns hex-encoded hash.
  """
  @spec hash_keccak256(String.t()) :: String.t()
  def hash_keccak256(_data), do: nif_not_loaded()

  @doc """
  Hex-encodes a string.
  """
  @spec hex_encode(String.t()) :: String.t()
  def hex_encode(_data), do: nif_not_loaded()

  @doc """
  Hex-decodes a string.
  Returns the decoded binary or raises on invalid hex.
  """
  @spec hex_decode(String.t()) :: String.t()
  def hex_decode(_data), do: nif_not_loaded()

  @doc """
  Parses a JSON string using Rust's serde_json.
  Returns the JSON string representation.
  """
  @spec json_parse(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def json_parse(_json_str), do: nif_not_loaded()

  @doc """
  Returns the Elixir type of a given value as a string.
  Uses Rust NIF type introspection for speed.
  """
  @spec lux_type_of(term()) :: String.t()
  def lux_type_of(_value), do: nif_not_loaded()

  @doc """
  Merges two maps, with values from the second map taking precedence.
  """
  @spec map_merge(map(), map()) :: map()
  def map_merge(_map1, _map2), do: nif_not_loaded()

  @doc """
  Sorts a list of comparable items.
  """
  @spec sort_list(list()) :: list()
  def sort_list(_list), do: nif_not_loaded()

  @doc """
  Returns true if the native library is loaded and functional.
  """
  @spec loaded?() :: boolean()
  def loaded? do
    Code.ensure_loaded?(:lux_native) and function_exported?(:lux_native, :add, 2)
  rescue
    _ -> false
  end

  @doc """
  Returns the native library version info.
  """
  @spec version() :: {:ok, String.t()} | {:error, String.t()}
  def version do
    if loaded?() do
      version_str = File.read!(Path.join(priv_dir(), "version.txt"))
      {:ok, String.trim(version_str)}
    else
      {:error, "Native library not loaded"}
    end
  end

  defp priv_dir do
    :code.priv_dir(:lux)
  end

  defp nif_not_loaded do
    if loaded?() do
      :erlang.nif_error(:nif_not_loaded)
    else
      raise """
      Native Rust library not loaded.

      Ensure you have Rust and cargo installed, then run:

          cd priv/rust && cargo build --release

      And add `rustler` to your project dependencies.
      """
    end
  end
end
