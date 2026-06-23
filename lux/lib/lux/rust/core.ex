defmodule Lux.Rust.Core do
  @moduledoc """
  Core FFI bindings to Rust using Rustler.
  
  This module serves as the lowest-level entry point for Rust integration,
  managing the Rustler NIF loading and exposing basic type conversions and
  error propagation utilities.
  """
  use Rustler, otp_app: :lux, crate: :lux_core, path: "priv/rust/lux_core"

  @doc """
  Add two numbers in Rust.
  """
  def add(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Concat two strings natively.
  """
  def concat_strings(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Safely divide two floats. Returns `{:ok, result}` or `{:error, reason}`.
  """
  def safe_divide(_a, _b), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Process a binary securely by reversing it in Rust.
  """
  def reverse_bytes(_binary), do: :erlang.nif_error(:nif_not_loaded)
end
