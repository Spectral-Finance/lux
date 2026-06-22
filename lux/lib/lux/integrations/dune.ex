defmodule Lux.Integrations.Dune do
  @moduledoc """
  Integration with the Dune Analytics API for executing and retrieving
  custom blockchain data queries.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Dune,
        base_url: System.get_env("DUNE_BASE_URL") || "https://api.dune.com/api/v1"

  And in your environment file (e.g., `dev.envrc` or `test.envrc`):

      DUNE_API_KEY="your-api-key"

  ## Authentication

  Authentication is handled via API key in the `X-Dune-Api-Key` header.
  """

  @type auth_type :: :custom
  @type api_key :: String.t()
  @type headers :: [{String.t(), String.t()}]

  @doc """
  Gets the configured Dune base URL.
  Defaults to "https://api.dune.com/api/v1" if not configured.
  """
  @spec base_url() :: String.t()
  def base_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:base_url, "https://api.dune.com/api/v1")
  end

  @doc """
  Gets the default headers for Dune API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"accept", "application/json"}
    ]
  end

  @doc """
  Gets the authentication configuration for Dune API requests.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :api_key,
      key: &__MODULE__.api_key/0
    }
  end

  @doc """
  Authenticates a lens for Dune API requests.
  Only adds the X-Dune-Api-Key header if it's not already present.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-dune-api-key" end) do
      nil ->
        %{lens | headers: [{"x-dune-api-key", api_key()} | headers]}
      _ ->
        lens
    end
  end

  @doc """
  Gets the Dune API key from configuration.
  """
  @spec api_key() :: String.t()
  def api_key do
    case Application.get_env(:lux, __MODULE__) do
      nil -> System.get_env("DUNE_API_KEY") || raise "DUNE_API_KEY is not configured"
      config -> Keyword.get(config, :api_key, System.get_env("DUNE_API_KEY")) || raise "DUNE_API_KEY is not configured"
    end
  end
end
