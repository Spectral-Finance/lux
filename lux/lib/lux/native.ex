defmodule Lux.Native do
  @moduledoc """
  Rust Core Integration Setup for Lux ($500).

  Provides the entry point and configuration for Rust NIFs compiled
  via Rustler. High-performance computations (cryptographic hashing,
  numerical analysis, data serialisation) run as native code loaded
  into the BEAM.

  ## Setup

  1. Add `rustler` to `mix.exs` dependencies.
  2. The Cargo workspace lives in `priv/rust/lux_native/`.
  3. Build: `mix rustler.compile` or automatic on `mix compile`.

  ## Architecture

  ```
  priv/rust/lux_native/
    Cargo.toml       <- crate manifest
    src/
      lib.rs         <- NIF exports via rustler::init!
      types.rs       <- Elixir <-> Rust type conversions
      error.rs       <- unified error type
      hash.rs        <- SHA-256 / keccak256 NIFs
      math.rs        <- statistical / numerical NIFs
  ```

  ## Usage

      # Once compiled, NIFs are called like regular Elixir functions:
      iex> Lux.Native.sha256("hello world")
      {:ok, "b94d27b9934d3e08..."}
  """

  # Rustler loads the NIF shared library.
  # Falls back to a pure-Elixir stub when the NIF is not compiled.
  use Rustler,
    otp_app: :lux,
    crate: :lux_native

  @doc "Computes SHA-256 hash of a binary string. Implemented as a Rust NIF."
  @spec sha256(binary()) :: {:ok, String.t()} | {:error, term()}
  def sha256(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Computes keccak256 hash (Ethereum-compatible) of a binary string."
  @spec keccak256(binary()) :: {:ok, String.t()} | {:error, term()}
  def keccak256(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Computes population standard deviation of a list of floats."
  @spec std_dev([number()]) :: {:ok, float()} | {:error, :empty_list}
  def std_dev(_values), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Sorts a list of floats using Rust's highly optimised pdqsort."
  @spec fast_sort([float()]) :: [float()]
  def fast_sort(_values), do: :erlang.nif_error(:nif_not_loaded)
end
