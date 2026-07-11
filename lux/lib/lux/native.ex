defmodule Lux.Native do
  @moduledoc """
  Core Native Implemented Functions (NIF) bridge using Rustler.
  
  This module loads the `lux_core` crate and exposes native 
  functions to be used by the Elixir application.
  """
  
  use Rustler, otp_app: :lux, crate: "lux_core"

  @doc """
  Reverses a string natively.
  """
  def reverse_string(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Parses a string into a float safely.
  Returns `{:ok, number}` or `{:error, reason}`.
  """
  def parse_number(_input), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Processes a payload struct/map natively.
  """
  def process_payload(_payload), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Transforms a complex nested struct using Rust.
  """
  def transform_complex(_data), do: :erlang.nif_error(:nif_not_loaded)
end
