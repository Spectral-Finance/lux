defmodule Lux.Integrations.Reservoir do
  @moduledoc """
  Integration with the Reservoir API for NFT marketplace data aggregation.
  Reservoir aggregates data from major platforms like OpenSea, Blur, X2Y2, and others.
  """

  @doc """
  Gets the configured Reservoir base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.reservoir.tools")
  end

  @doc """
  Gets the default headers for Reservoir API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for Reservoir API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.authenticate/1
    }
  end

  @doc """
  Authenticates a lens for Reservoir API requests.
  Only adds the x-api-key header if the key is present.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case api_key() do
      nil -> lens
      key -> %{lens | headers: headers ++ [{"x-api-key", key}]}
    end
  end

  @spec api_key() :: String.t() | nil
  def api_key do
    case Application.fetch_env(:lux, :api_keys) do
      {:ok, keys} -> Keyword.get(keys, :reservoir)
      :error -> nil
    end
  end
end
