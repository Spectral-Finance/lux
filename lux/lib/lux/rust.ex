defmodule Lux.Rust do
  @moduledoc """
  Provides functions for interacting with Rust-based components.

  The ~R sigil is used to reference a Rust component by name.
  """

  @doc """
  Returns a list of all registered Rust components.
  """
  def list_components do
    Lux.Native.list_components()
  end

  @doc """
  Calls a Rust component by name.
  """
  def call(name, input) do
    Lux.Native.call(name, input)
  end

  @doc """
  A sigil that references a Rust component.
  ~R"Math" will be interpreted as {:rust, "Math"}.
  """
  defmacro sigil_R({:<<>>, _meta, [name]}, _modifiers) do
    quote do: {:rust, unquote(name)}
  end
end
