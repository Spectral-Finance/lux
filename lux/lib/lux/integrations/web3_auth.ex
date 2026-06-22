defmodule Lux.Integrations.Web3Auth do
  @moduledoc """
  Configuration and integration settings for the Web3 Authentication and Authorization Framework.
  """
  
  @doc """
  Gets the default RPC URL for Web3Auth operations.
  """
  @spec default_rpc_url() :: String.t()
  def default_rpc_url do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:rpc_url, "https://cloudflare-eth.com")
  end

  @doc """
  Gets the session secret for generating session tokens.
  """
  @spec session_secret() :: String.t()
  def session_secret do
    :lux
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:session_secret, System.get_env("WEB3_AUTH_SESSION_SECRET", "default_insecure_secret_for_dev_only"))
  end
end
