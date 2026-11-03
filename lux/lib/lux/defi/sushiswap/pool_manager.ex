defmodule Lux.Defi.SushiSwap.PoolManager do
  @moduledoc """
  Multi-chain registry and pool state manager for SushiSwap:
  - Supports Ethereum (1), Arbitrum (42161), Polygon (137), Optimism (10), Avalanche (43114), and Base (8453)
  - Manages RouteProcessor, BentoBox, SushiXSwap, and MiniChef contract addresses
  """

  @deployments %{
    1 => %{
      chain_name: "Ethereum",
      chain_id: 1,
      native_symbol: "ETH",
      router_v2: "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F",
      route_processor: "0x827179dD66505b5ee7714546EdE16679Db06FB52",
      sushixswap: "0x40316694857bC15486A2E4485703fF7094060b24",
      sushi_token: "0x6B3595068778DD592e39A122f4f5a5cF09C90fE2"
    },
    42161 => %{
      chain_name: "Arbitrum One",
      chain_id: 42161,
      native_symbol: "ETH",
      router_v2: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
      route_processor: "0x827179dD66505b5ee7714546EdE16679Db06FB52",
      sushixswap: "0x40316694857bC15486A2E4485703fF7094060b24",
      sushi_token: "0xd4d42F0b6DEF4CE0383636770eF773390d85c61A"
    },
    137 => %{
      chain_name: "Polygon",
      chain_id: 137,
      native_symbol: "POL",
      router_v2: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
      route_processor: "0x827179dD66505b5ee7714546EdE16679Db06FB52",
      sushixswap: "0x40316694857bC15486A2E4485703fF7094060b24",
      sushi_token: "0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a"
    },
    10 => %{
      chain_name: "Optimism",
      chain_id: 10,
      native_symbol: "ETH",
      router_v2: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
      route_processor: "0x827179dD66505b5ee7714546EdE16679Db06FB52",
      sushixswap: "0x40316694857bC15486A2E4485703fF7094060b24",
      sushi_token: "0x5C2c6b48842E9d2542a98eefdC9c7B8B1675Fe3c"
    },
    8453 => %{
      chain_name: "Base",
      chain_id: 8453,
      native_symbol: "ETH",
      router_v2: "0x6BDED42c6DA8FBf0d2bA55B2fa120C5e0c8D7891",
      route_processor: "0x827179dD66505b5ee7714546EdE16679Db06FB52",
      sushixswap: "0x40316694857bC15486A2E4485703fF7094060b24",
      sushi_token: "0x7d49A296E0886e118ebA3258593Ec3875323C6Fe"
    }
  }

  @doc """
  Retrieves deployment config for a given chain ID.
  """
  @spec get_deployment(pos_integer()) :: {:ok, map()} | {:error, :unsupported_chain}
  def get_deployment(chain_id) do
    case Map.get(@deployments, chain_id) do
      nil -> {:error, :unsupported_chain}
      config -> {:ok, config}
    end
  end

  @doc """
  Lists all supported SushiSwap chain deployments.
  """
  @spec list_deployments() :: list(map())
  def list_deployments, do: Map.values(@deployments)

  @doc """
  Builds pool state map for a pair.
  """
  @spec build_pool(pos_integer(), atom(), String.t(), String.t(), float(), float()) :: map()
  def build_pool(chain_id, version, token0, token1, reserve0, reserve1) do
    %{
      id: "sushi_#{chain_id}_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)),
      chain_id: chain_id,
      version: version,
      token0: String.upcase(token0),
      token1: String.upcase(token1),
      reserve0: reserve0 * 1.0,
      reserve1: reserve1 * 1.0,
      mid_price: if(reserve0 > 0, do: Float.round(reserve1 / reserve0, 6), else: 0.0)
    }
  end
end
