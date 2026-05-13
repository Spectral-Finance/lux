defmodule Lux.Integrations.DeFiAnalytics do
  @moduledoc """
  Shared DeFi analytics integration settings for DeFiLlama and Dune.
  """

  @defillama_base_url "https://api.llama.fi"
  @defillama_yields_url "https://yields.llama.fi"
  @dune_base_url "https://api.dune.com/api/v1"

  @doc "Returns the DeFiLlama protocol API base URL."
  def defillama_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:defillama_base_url, @defillama_base_url)
  end

  @doc "Returns the DeFiLlama yields API base URL."
  def defillama_yields_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:defillama_yields_url, @defillama_yields_url)
  end

  @doc "Returns the Dune API base URL."
  def dune_base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:dune_base_url, @dune_base_url)
  end

  @doc "Returns configured Dune API key, if present."
  def dune_api_key do
    :lux
    |> Application.get_env(:api_keys, [])
    |> Keyword.get(:dune)
  end

  @doc "Returns normalized JSON API error tuples."
  def classify_error(status, body) do
    message = error_message(body)

    case status do
      400 -> {:bad_request, message}
      401 -> :invalid_token
      403 -> {:forbidden, message}
      404 -> {:not_found, message}
      429 -> {:rate_limited, message}
      _ -> {status, message}
    end
  end

  defp error_message(%{"error" => %{"message" => message}}) when is_binary(message), do: message
  defp error_message(%{"error" => message}) when is_binary(message), do: message
  defp error_message(%{"message" => message}) when is_binary(message), do: message
  defp error_message(message) when is_binary(message), do: message
  defp error_message(body), do: inspect(body)
end
