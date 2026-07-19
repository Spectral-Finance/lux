defmodule Lux.Native do
  @moduledoc """
  Rust Core Integration Setup for Lux.

  Provides the entry point and configuration for Rust NIFs compiled
  via Rustler. High-performance computations (cryptographic hashing,
  JSON serialisation, type inspection) run as native code loaded
  into the BEAM.

  ## Architecture

  ```
  priv/rust/lux_native/
    Cargo.toml
    src/
      lib.rs      — NIF exports
      types.rs    — Type inspection
      crypto.rs   — Cryptographic utilities
      error.rs    — Error types
  ```
  """

  use Rustler,
    otp_app: :lux,
    crate: :lux_native

  @doc "Computes SHA-256 hash of the given string."
  @spec hash_sha256(String.t()) :: String.t()
  def hash_sha256(_data), do: error()

  @doc "Pretty-prints a JSON string."
  @spec serialize_json(String.t()) :: String.t()
  def serialize_json(_data), do: error()

  @doc "Parses a JSON string and returns the compact representation."
  @spec deserialize_json(String.t()) :: String.t()
  def deserialize_json(_data), do: error()

  @doc "Returns the Erlang term type as a string."
  @spec type_to_string(term()) :: String.t()
  def type_to_string(_term), do: error()

  @doc "Adds two integers."
  @spec add_numbers(integer(), integer()) :: integer()
  def add_numbers(_a, _b), do: error()

  @doc "Multiplies two floats."
  @spec multiply_numbers(float(), float()) :: float()
  def multiply_numbers(_a, _b), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
