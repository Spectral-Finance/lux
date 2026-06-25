defmodule Lux.LLM.Provider do
  @moduledoc """
  Behaviour for LLM providers in Lux
  """

  @doc """
  Callback for generating text completions
  """
  @callback generate(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}

  @doc """
  Callback for getting provider information
  """
  @callback info() :: map()

  @doc """
  Callback for getting model information
  """
  @callback model_info(String.t()) :: map()

  @doc """
  Callback for getting provider cost information
  """
  @callback cost(String.t(), integer()) :: float()

  @optional_callbacks model_info: 1, cost: 2

  @doc """
  Generates text using the provider with given options
  """
  @spec generate(atom(), String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def generate(provider, prompt, opts \\ []) do
    provider.generate(prompt, opts)
  end

  @doc """
  Gets information about the provider
  """
  @spec info(atom()) :: map()
  def info(provider) do
    provider.info()
  end
end