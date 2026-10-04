defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Configuration and authentication utilities for Coinbase Advanced Trade & Exchange integration.

  Supports:
  - Modern CDP API Keys (ECDSA P-256 JWT auth)
  - Legacy API Keys & HMAC-SHA256 signature auth
  - Sandbox and Production environments
  """

  @default_prod_base_url "https://api.coinbase.com/api/v3/brokerage"
  @default_sandbox_base_url "https://api-public.sandbox.exchange.coinbase.com"
  @default_ws_url "wss://advanced-trade-ws.coinbase.com"

  @doc """
  Returns whether Coinbase integration is running in sandbox mode.
  """
  @spec sandbox?() :: boolean()
  def sandbox? do
    get_config(:sandbox, false)
  end

  @doc """
  Gets the configured REST API base URL.
  """
  @spec base_url() :: String.t()
  def base_url do
    case get_config(:base_url, nil) do
      url when is_binary(url) and byte_size(url) > 0 -> url
      _ -> if sandbox?(), do: @default_sandbox_base_url, else: @default_prod_base_url
    end
  end

  @doc """
  Gets the configured WebSocket feed URL.
  """
  @spec ws_url() :: String.t()
  def ws_url do
    get_config(:ws_url, @default_ws_url)
  end

  @doc """
  Gets the CDP API Key Name (e.g. organizations/{org_id}/apiKeys/{key_id}).
  """
  @spec cdp_key_name() :: String.t() | nil
  def cdp_key_name do
    get_config(:cdp_key_name, System.get_env("COINBASE_CDP_KEY_NAME") || System.get_env("CDP_API_KEY_NAME"))
  end

  @doc """
  Gets the CDP ECDSA private key (PEM string or path).
  """
  @spec cdp_private_key() :: String.t() | nil
  def cdp_private_key do
    get_config(:cdp_private_key, System.get_env("COINBASE_CDP_PRIVATE_KEY") || System.get_env("CDP_PRIVATE_KEY"))
  end

  @doc """
  Gets the legacy Coinbase API Key.
  """
  @spec api_key() :: String.t() | nil
  def api_key do
    get_config(:api_key, System.get_env("COINBASE_API_KEY"))
  end

  @doc """
  Gets the legacy Coinbase API Secret.
  """
  @spec api_secret() :: String.t() | nil
  def api_secret do
    get_config(:api_secret, System.get_env("COINBASE_API_SECRET"))
  end

  @doc """
  Gets the legacy API Passphrase.
  """
  @spec passphrase() :: String.t() | nil
  def passphrase do
    get_config(:passphrase, System.get_env("COINBASE_PASSPHRASE"))
  end

  @doc """
  Standard headers for Coinbase REST requests.
  """
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Returns a credentials map for passing into Python prisms or lenses.
  """
  @spec credentials() :: map()
  def credentials do
    %{
      api_key_name: cdp_key_name(),
      private_key: cdp_private_key(),
      api_key: api_key(),
      api_secret: api_secret(),
      passphrase: passphrase(),
      base_url: base_url(),
      ws_url: ws_url(),
      sandbox: sandbox?()
    }
  end

  defp get_config(key, default) do
    case Application.get_env(:lux, __MODULE__) do
      nil -> default
      config when is_list(config) -> Keyword.get(config, key, default)
      config when is_map(config) -> Map.get(config, key, default)
      _ -> default
    end
  end
end
