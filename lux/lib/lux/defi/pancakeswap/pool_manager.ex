defmodule Lux.Defi.PancakeSwap.PoolManager do
  @moduledoc """
  Multi-chain PancakeSwap pool manager supporting BSC, Ethereum, Arbitrum, Base, and zkSync Era:
  - Contract address registry for V2, V3, and MasterChef deployments
  - Pool state representation (V2 constant product and V3 concentrated liquidity)
  - Multi-chain chain ID resolution and token mapping
  """

  @deployments %{
    56 => %{
      chain_name: "BNB Smart Chain",
      chain_id: 56,
      native_symbol: "BNB",
      factory_v3: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
      router_v3: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
      masterchef_v3: "0x556B9306565093C855AEA9AE92A594704c2Cd59e",
      cake_token: "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
    },
    1 => %{
      chain_name: "Ethereum",
      chain_id: 1,
      native_symbol: "ETH",
      factory_v3: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
      router_v3: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
      masterchef_v3: "0x69Fd81e9d150241A4eEbC4Eeb8364F7b03658f8b",
      cake_token: "0x152649eA73beAb11c88499f8211f45513e9aB34b"
    },
    42161 => %{
      chain_name: "Arbitrum One",
      chain_id: 42161,
      native_symbol: "ETH",
      factory_v3: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
      router_v3: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
      masterchef_v3: "0x4b5840A6e9A74E51Ff7b4eC62956f4d38eEbC0d7",
      cake_token: "0x1b896893dfc86bb67cf5788837e9357364321efe"
    },
    8453 => %{
      chain_name: "Base",
      chain_id: 8453,
      native_symbol: "ETH",
      factory_v3: "0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865",
      router_v3: "0x13f4EA83D0bd40E75C8222255bc855a974568Dd4",
      masterchef_v3: "0x126E2C95f70D7C589Acfe7343b4A65709971DDEB",
      cake_token: "0x18a1bc18de55D93fb2B09532f796B2417770E1a3"
    }
  }

  @type chain_id :: 56 | 1 | 42161 | 8453
  @type pool_type :: :v2 | :v3 | :stableswap

  @type pool :: %{
          id: String.t(),
          chain_id: chain_id(),
          pool_type: pool_type(),
          token0: String.t(),
          token1: String.t(),
          fee: pos_integer(),
          pool_address: String.t(),
          reserve0: non_neg_integer(),
          reserve1: non_neg_integer(),
          total_supply: non_neg_integer()
        }

  @doc """
  Retrieves PancakeSwap deployment metadata for a chain ID.
  """
  @spec get_deployment(pos_integer()) :: {:ok, map()} | {:error, :unsupported_chain}
  def get_deployment(chain_id) do
    case Map.get(@deployments, chain_id) do
      nil -> {:error, :unsupported_chain}
      dep -> {:ok, dep}
    end
  end

  @doc """
  Lists all supported chain deployments.
  """
  @spec list_deployments() :: list(map())
  def list_deployments, do: Map.values(@deployments)

  @doc """
  Builds a structured pool state.
  """
  @spec build_pool(map()) :: {:ok, pool()} | {:error, term()}
  def build_pool(params) when is_map(params) do
    chain_id = Map.get(params, :chain_id) || Map.get(params, "chain_id", 56)
    pool_type = Map.get(params, :pool_type) || Map.get(params, "pool_type", :v3)
    token0 = Map.get(params, :token0) || Map.get(params, "token0")
    token1 = Map.get(params, :token1) || Map.get(params, "token1")
    fee = Map.get(params, :fee) || Map.get(params, "fee", 2500)
    pool_addr = Map.get(params, :pool_address) || Map.get(params, "pool_address", "0x0000000000000000000000000000000000000000")

    cond do
      is_nil(token0) or is_nil(token1) ->
        {:error, :missing_tokens}

      true ->
        pool_id = "pcs_#{chain_id}_" <> (:crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower))

        pool = %{
          id: pool_id,
          chain_id: chain_id,
          pool_type: pool_type,
          token0: String.downcase(token0),
          token1: String.downcase(token1),
          fee: fee,
          pool_address: String.downcase(pool_addr),
          reserve0: Map.get(params, :reserve0, 0),
          reserve1: Map.get(params, :reserve1, 0),
          total_supply: Map.get(params, :total_supply, 0)
        }

        {:ok, pool}
    end
  end
end
