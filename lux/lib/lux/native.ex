defmodule Lux.Native do
  @moduledoc """
  NIF bindings to Rust native code for high-performance operations.

  Provides:
  - JSON round-trip validation and transformation
  - JSON type validation
  - SHA-256 hashing
  - Performance benchmarking

  ## Usage

      iex> Lux.Native.json_roundtrip(~s({"key": "value"}))
      {:ok, ~s({"key":"value"})}

      iex> Lux.Native.validate_json(~s("hello"), "string")
      {:ok, "valid"}

      iex> Lux.Native.sha256_hex("hello")
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  """

  use Rustler, otp_app: :lux, crate: "lux_native"

  @doc "Parse JSON, validate, and re-serialize (round-trip)."
  @spec json_roundtrip(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def json_roundtrip(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Validate JSON string against a type descriptor."
  @spec validate_json(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_json(_input, _type_name), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Compute SHA-256 hash and return hex string."
  @spec sha256_hex(String.t()) :: String.t()
  def sha256_hex(_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Benchmark JSON round-trip parsing for N iterations. Returns microseconds."
  @spec bench_json_roundtrip(String.t(), non_neg_integer()) :: non_neg_integer()
  def bench_json_roundtrip(_input, _iterations), do: :erlang.nif_error(:nif_not_loaded)
end
