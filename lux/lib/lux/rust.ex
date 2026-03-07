defmodule Lux.Rust do
  @moduledoc """
  Core interface for Rust integration in Lux.
  
  Provides a robust type system and efficient serialization layer
  using native Erlang Term Format (ETF).
  """

  use Rustler,
    otp_app: :lux,
    crate: "lux_rust"

  @doc """
  Evaluates a Rust function with native term serialization.
  """
  def call(_module, _function, _args), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Sigil for inline Rust code.
  """
  defmacro sigil_RUST({:<<>>, _meta, [string]}, _modifiers) do
    quote do: Lux.Rust.eval(unquote(string))
  end

  def eval(code, opts \\ []) do
    # Implementation for dynamic compilation (similar to Lux.Cargo)
    # but with native type mapping.
    {:error, "Dynamic eval not yet implemented with native serialization"}
  end
end
