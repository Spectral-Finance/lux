defmodule Lux.Config do
  @moduledoc """
  Central configuration for Lux application
  """

  @type api_key :: String.t()
  @type eth_key :: String.t()
  @type eth_address :: String.t()

  def runtime(key, path, default \\ nil) do
    {:runtime_config, key, path, default}
  end

  def resolve({:runtime_config, key, path, default}) do
    case Application.get_env(:lux, key) do
      nil -> default
      config -> get_in(config, path)
    end
  end

  def resolve(value) do
    value
  end

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

  @doc """
  Gets the Etherscan API key from configuration.
  Raises if the key is not configured.
  """
  @spec etherscan_api_key() :: api_key()
  def etherscan_api_key do
    get_required_key(:api_keys, :etherscan)
  end

  @doc """
  Checks if the configured Etherscan API key is a Pro subscription.
  Returns false by default unless explicitly configured as true.
  """
  @spec etherscan_api_key_pro?() :: boolean()
  def etherscan_api_key_pro? do
    :lux
    |> Application.fetch_env!(:api_keys)
    |> Keyword.get(:etherscan_pro, false)
  end

  @doc """
  Gets the Etherscan API URL.
  Uses the V2 API format with chainid parameter.
  """
  @spec etherscan_api_url() :: String.t()
  def etherscan_api_url do
    "https://api.etherscan.io/v2/api"
  end

  @doc """
  Gets the chain ID for a specific network.
  """
  @spec etherscan_chain_id(atom()) :: String.t()
  def etherscan_chain_id(network \\ :ethereum) do
    case network do
      :ethereum -> "1"
      :goerli -> "5"
      :sepolia -> "11155111"
      :polygon -> "137"
      :arbitrum -> "42161"
      :optimism -> "10"
      :base -> "8453"
      :avalanche -> "43114"
      _ -> "1" # Default to Ethereum mainnet
    end
  end

  @doc """
  Gets the Hyperliquid account's private key from configuration.
  Raises if the key is not configured.
  """
  @spec hyperliquid_account_key() :: eth_key()
  def hyperliquid_account_key do
    get_required_key(:accounts, :hyperliquid_private_key)
  end

  @doc """
  Gets the Hyperliquid account's address from configuration.
  Returns empty string if not configured.
  """
  @spec hyperliquid_account_address() :: eth_address()
  def hyperliquid_account_address do
    :lux
    |> Application.fetch_env!(:accounts)
    |> Keyword.get(:hyperliquid_address, "")
  end

  @doc """
  Gets the configured Hyperliquid API URL.
  """
  @spec hyperliquid_api_url() :: String.t()
  def hyperliquid_api_url do
    Application.fetch_env!(:lux, :accounts)[:hyperliquid_api_url]
  end

  @doc """
  Retrieves the wallet address
  """
  @spec wallet_address() :: String.t()
  def wallet_address do
    :lux
    |> Application.fetch_env!(:accounts)
    |> Keyword.get(:wallet_address, "")
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
