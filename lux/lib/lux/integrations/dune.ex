defmodule Lux.Integrations.Dune do
  @moduledoc """
  Integration with Dune Analytics API.

  Allows fetching query results and running queries using the Dune v1 API.

  ## Configuration

  The API key can be provided via application config or environment variable:

      # config/config.exs
      config :lux, Lux.Integrations.Dune,
        api_key: "your-dune-api-key"

  Or via the `DUNE_API_KEY` environment variable.
  """

  @doc """
  Gets the configured Dune base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    "https://api.dune.com/api/v1"
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
  Authenticates a lens for Dune API requests by injecting the x-dune-api-key header.

  Returns the lens unchanged if the header is already present.
  Raises a clear error message if no API key is configured.
  """
  @spec authenticate(map()) :: map()
  def authenticate(%{headers: headers} = lens) do
    case Enum.find(headers, fn {key, _} -> String.downcase(key) == "x-dune-api-key" end) do
      nil ->
        case api_key() do
          nil ->
            raise ArgumentError,
                  "Dune API key not configured. " <>
                    "Set it via `config :lux, Lux.Integrations.Dune, api_key: \"...\"` " <>
                    "or via the DUNE_API_KEY environment variable."

          key ->
            %{lens | headers: [{"x-dune-api-key", key} | headers]}
        end

      _ ->
        lens
    end
  end

  @doc """
  Gets the Dune API key from application config or environment variable.

  Returns `nil` if neither is configured (caller should handle gracefully).
  """
  @spec api_key() :: String.t() | nil
  def api_key do
    config = Application.get_env(:lux, __MODULE__, [])
    Keyword.get(config, :api_key) || System.get_env("DUNE_API_KEY")
  end
end
