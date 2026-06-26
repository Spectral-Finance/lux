defmodule Lux do
  @moduledoc """
  Lux is a framework for building intelligent, adaptive, and collaborative multi-agent systems,
  with comprehensive Web3 and DeFi integrations including Uniswap V3 liquidity management.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Lux.hello()
      :world

  def version do
    "0.1.0"
  end

  @doc """
  Returns the Uniswap V3 integration module.
  """
  @spec uniswap_v3 :: module()
  def uniswap_v3 do
    Lux.Integrations.Uniswap.V3
  end
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
