defmodule Lux do
  @moduledoc """
  Documentation for `Lux`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Lux.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """
  Check if a module is a beam.
  """
  def beam?(module) when is_atom(module) do
    function_exported?(module, :__steps__, 0) and function_exported?(module, :run, 2)
  end

  def beam?(_), do: false

  @doc """
  Check if a module is a prism.
  """
  def prism?(module) when is_atom(module) do
    function_exported?(module, :handler, 2)
  end

  def prism?(_), do: false

  @doc """
  Check if a module is a lens.
  """
  def lens?(module) when is_atom(module) do
    function_exported?(module, :focus, 2)
  end

  def lens?(_), do: false
end
