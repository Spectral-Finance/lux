defmodule Lux.Lenses.Etherscan.ChainConfig do
  @moduledoc """
  Module for managing chain configuration settings.
  """

  @chains %{
    "mainnet" => %{id: 1, name: "Ethereum Mainnet", rpc_url: "https://mainnet.infura.io/v3/YOUR_INFURA_PROJECT_ID"},
    "ropsten" => %{id: 3, name: "Ropsten Testnet", rpc_url: "https://ropsten.infura.io/v3/YOUR_INFURA_PROJECT_ID"},
    "rinkeby" => %{id: 4, name: "Rinkeby Testnet", rpc_url: "https://rinkeby.infura.io/v3/YOUR_INFURA_PROJECT_ID"},
    "goerli" => %{id: 5, name: "Goerli Testnet", rpc_url: "https://goerli.infura.io/v3/YOUR_INFURA_PROJECT_ID"}
  }

  @doc """
  Retrieves the configuration for a given chain.
  """
  def get_chain_config(chain_id) do
    Map.get(@chains, chain_id)
  end

  @doc """
  Validates if the provided chain ID is supported.
  """
  def validate_chain_id(chain_id) when is_integer(chain_id) and chain_id > 0 do
    case get_chain_config(chain_id) do
      nil -> {:error, "Unsupported chain ID: #{chain_id}"}
      _ -> {:ok, chain_id}
    end
  end

  @doc """
  Validates if the provided chain name is supported.
  """
  def validate_chain_name(chain_name) when is_binary(chain_name) do
    case Enum.any?(@chains, fn {_, config} -> config[:name] == chain_name end) do
      true -> {:ok, chain_name}
      false -> {:error, "Unsupported chain name: #{chain_name}"}
    end
  end
end