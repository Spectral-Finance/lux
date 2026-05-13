defmodule Lux.Integrations.CurveFinance do
  @moduledoc """
  Shared settings and helpers for Curve Finance stablecoin management.
  """

  @api_base_url "https://api.curve.finance/v1"

  @chains [
    :ethereum,
    :arbitrum,
    :avalanche,
    :base,
    :bsc,
    :fantom,
    :optimism,
    :polygon,
    :xdai,
    :zksync
  ]

  @registries [
    :main,
    :factory,
    :crypto,
    :"factory-crypto",
    :"factory-crvusd",
    :"factory-stable-ng",
    :"factory-twocrypto",
    :"factory-tricrypto"
  ]

  @stablecoin_symbols MapSet.new([
                        "3CRV",
                        "BUSD",
                        "CRVUSD",
                        "DAI",
                        "FRAX",
                        "GHO",
                        "LUSD",
                        "PYUSD",
                        "SUSD",
                        "USDC",
                        "USDE",
                        "USDP",
                        "USDT",
                        "USD0",
                        "USD1",
                        "USDD",
                        "USDS",
                        "TUSD"
                      ])

  @doc "Returns default Curve API client settings."
  @spec client_settings() :: map()
  def client_settings do
    %{
      base_url: @api_base_url,
      headers: [{"accept", "application/json"}]
    }
  end

  @doc "Returns supported Curve blockchain ids."
  @spec chains() :: [atom()]
  def chains, do: @chains

  @doc "Returns supported Curve registry ids."
  @spec registries() :: [atom()]
  def registries, do: @registries

  @doc "Converts chain atoms to Curve API blockchain ids."
  @spec chain_id(atom() | String.t()) :: String.t()
  def chain_id(:xdai), do: "xdai"
  def chain_id(:zksync), do: "zksync"
  def chain_id(chain) when is_atom(chain), do: Atom.to_string(chain)
  def chain_id(chain) when is_binary(chain), do: chain

  @doc "Converts registry atoms to Curve API registry ids."
  @spec registry_id(atom() | String.t()) :: String.t()
  def registry_id(registry) when is_atom(registry), do: Atom.to_string(registry)
  def registry_id(registry) when is_binary(registry), do: registry

  @doc "Returns true when a symbol is treated as a stablecoin for pool analysis."
  @spec stablecoin_symbol?(String.t()) :: boolean()
  def stablecoin_symbol?(symbol) when is_binary(symbol) do
    symbol
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/, "")
    |> then(&MapSet.member?(@stablecoin_symbols, &1))
  end

  def stablecoin_symbol?(_symbol), do: false
end
