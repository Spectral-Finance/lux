defmodule Lux.Rust.Types do
  @moduledoc """
  Provides macros and utilities for mapping Elixir types to Rust.
  """

  defmacro defrust_struct(name, fields) do
    quote do
      defmodule unquote(name) do
        @derive {Jason.Encoder, only: unquote(fields)}
        defstruct unquote(fields)
      end
    end
  end
end
