defmodule Lux.Native do
  @moduledoc """
  Rust Core Integration for Lux.

  Provides native Rust NIFs for high-performance computations,
  including cryptographic hashing, JSON serialisation, type
  inspection, and Cargo package management.
  """

  use Rustler, otp_app: :lux, crate: :lux_native

  # --- Core NIFs (#94) ---
  @spec hash_sha256(String.t()) :: String.t()
  def hash_sha256(_data), do: error()
  @spec serialize_json(String.t()) :: String.t()
  def serialize_json(_data), do: error()
  @spec deserialize_json(String.t()) :: String.t()
  def deserialize_json(_data), do: error()
  @spec type_to_string(term()) :: String.t()
  def type_to_string(_term), do: error()
  @spec add_numbers(integer(), integer()) :: integer()
  def add_numbers(_a, _b), do: error()
  @spec multiply_numbers(float(), float()) :: float()
  def multiply_numbers(_a, _b), do: error()

  # --- Cargo Management NIFs (#100) ---
  @spec cargo_generate_toml(String.t(), String.t(), [{String.t(), String.t()}]) :: String.t()
  def cargo_generate_toml(_name, _version, _deps), do: error()
  @spec cargo_resolve_deps(String.t()) :: [{String.t(), String.t()}]
  def cargo_resolve_deps(_toml), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
