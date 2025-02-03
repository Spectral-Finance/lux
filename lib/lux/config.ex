defmodule Lux.Config do
  @moduledoc """
  Central configuration for Lux application
  """

  @type api_key :: String.t()

  @doc """
  Gets the Alchemy API key from configuration.
  Raises if the key is not configured.
  """
  @spec alchemy_api_key() :: api_key()
  def alchemy_api_key do
    get_required_key(:api_keys, :alchemy)
  end

  @doc """
  Gets the OpenAI API key from configuration.
  Raises if the key is not configured.
  """
  @spec openai_api_key() :: api_key()
  def openai_api_key do
    get_required_key(:api_keys, :openai)
  end

  @spec openweather_api_key() :: api_key()
  def openweather_api_key do
    get_required_key(:api_keys, :openweather)
  end

  @spec transpose_api_key() :: api_key()
  def transpose_api_key do
    case Application.get_env(:lux, :env) do
      :test -> get_required_key(:api_keys, :integration_transpose)
      _ -> get_required_key(:api_keys, :transpose)
    end
  end

  @doc false
  defp get_required_key(group, key) do
    :lux
    |> Application.fetch_env!(group)
    |> Keyword.get(key)
    |> case do
      nil -> raise "#{key} is not configured in :#{group}!"
      value -> value
    end
  end
end
