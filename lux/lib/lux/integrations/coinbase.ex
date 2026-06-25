defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Common settings and functions for Coinbase Advanced Trade API integration.

  Uses the `coinbase-advanced-py` SDK for REST and WebSocket operations.
  Authentication is handled via API key/secret environment variables
  (COINBASE_API_KEY, COINBASE_API_SECRET) or a JWT key file.
  """

  @doc """
  Returns the REST API base path used by Coinbase Advanced Trade.
  """
  @spec api_prefix() :: String.t()
  def api_prefix, do: "/api/v3/brokerage"

  @doc """
  Returns common headers for Coinbase API requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"Content-Type", "application/json"},
      {"CB-PRO-TIMEOUT-OVERRIDE", "true"}
    ]
  end

  @doc """
  Returns auth settings for authenticated Coinbase API calls.
  Supports both API key/secret and JWT key file approaches.
  """
  @spec auth() :: map()
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Coinbase authentication headers to a lens.
  Tries API key/secret first, falls back to JWT key file.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    api_key = Lux.Config.coinbase_api_key()
    api_secret = Lux.Config.coinbase_api_secret()

    if api_key && api_secret do
      %{lens | headers: lens.headers ++ [{"CB-ACCESS-KEY", api_key}]}
    else
      key_file = Lux.Config.coinbase_key_file()
      if key_file && key_file != "" do
        %{lens | headers: lens.headers ++ [{"CB-PRO-TIMEOUT-OVERRIDE", "true"}]}
      else
        lens
      end
    end
  end

  @doc """
  Builds the subscription message for WebSocket channels.
  Used internally by the WebSocket prism.
  """
  @spec build_ws_subscribe_msg(product_ids :: [String.t()], channels :: [String.t()]) :: map()
  def build_ws_subscribe_msg(product_ids, channels) do
    %{
      type: "subscribe",
      product_ids: product_ids,
      channels: channels
    }
  end

  @doc """
  Validates a product ID format (e.g. "BTC-USD", "ETH-USD").
  """
  @spec valid_product_id?(String.t()) :: boolean()
  def valid_product_id?(product_id) do
    Regex.match?(~r/^[A-Z]+-[A-Z]+$/, product_id)
  end
end
