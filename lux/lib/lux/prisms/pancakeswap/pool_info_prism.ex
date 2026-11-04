defmodule Lux.Prisms.PancakeSwap.PoolInfoPrism do
  @moduledoc """
  Reads a PancakeSwap MasterChef V2 farm pool from chain.

  Returns the LP token, allocation points, CAKE emissions and, when `cake_price_usd` and
  `pool_tvl_usd` are supplied, the farming APR (as a fraction: `0.25` means 25%).

  The pool's yearly CAKE emission is
  `cakePerBlock * allocPoint / totalAllocPoint * blocks_per_year`. `blocks_per_year`
  defaults to the chain's value in `Lux.Integrations.PancakeSwap.chains/0`; pass it
  explicitly if the chain's block time changes.

  ## Example

      iex> Lux.Prisms.PancakeSwap.PoolInfoPrism.run(%{
      ...>   chain: "bsc",
      ...>   pool_id: 2,
      ...>   cake_price_usd: 2.5,
      ...>   pool_tvl_usd: 40_000_000
      ...> })
      {:ok,
       %{
         chain: "bsc",
         chain_id: 56,
         pool_id: 2,
         lp_token: "0x0ed7e52944161450477ee417de9cd3a859b14fd0",
         alloc_point: 1000,
         total_alloc_point: 10_000,
         cake_per_year: "...",
         apr: 0.31
         # ...
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap Pool Info",
    description: "Reads a PancakeSwap MasterChef V2 farm pool and computes its farming APR",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, description: "Chain name or id (default: bsc)", default: "bsc"},
        pool_id: %{type: :integer, minimum: 0, description: "MasterChef pool id (pid)"},
        masterchef: %{type: :string, description: "Override the MasterChef contract address"},
        rpc_url: %{type: :string, description: "Override the JSON-RPC endpoint"},
        blocks_per_year: %{type: :integer, description: "Override the chain's blocks per year"},
        cake_price_usd: %{type: :number, description: "CAKE price in USD (enables APR)"},
        pool_tvl_usd: %{type: :number, description: "Pool TVL in USD (enables APR)"}
      },
      required: ["pool_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string},
        chain_id: %{type: :integer},
        masterchef: %{type: :string},
        pool_id: %{type: :integer},
        pool_length: %{type: :integer},
        lp_token: %{type: :string},
        is_regular: %{type: :boolean},
        alloc_point: %{type: :integer},
        total_alloc_point: %{type: :integer},
        total_boosted_share: %{type: :string},
        cake_per_block: %{type: :string, description: "Wei per block, as a string"},
        cake_per_year: %{type: :string, description: "Wei per year for this pool, as a string"},
        apr: %{type: :number, description: "Farming APR as a fraction (only with prices)"}
      },
      required: ["chain", "pool_id", "lp_token", "alloc_point", "cake_per_year"]
    }

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client

  @wei_per_token 1.0e18

  def handler(input, _ctx) do
    with {:ok, chain} <- PancakeSwap.fetch_chain(PancakeSwap.field(input, :chain, "bsc")),
         {:ok, pool_id} <- validate_pool_id(PancakeSwap.field(input, :pool_id)),
         {:ok, masterchef} <-
           PancakeSwap.address(chain, :masterchef_v2, PancakeSwap.field(input, :masterchef)),
         {:ok, pool} <- read_pool(chain, masterchef, pool_id, PancakeSwap.rpc_opts(input)) do
      blocks_per_year = PancakeSwap.field(input, :blocks_per_year) || chain.blocks_per_year

      output =
        Map.merge(pool, %{
          chain: chain.name,
          chain_id: chain.id,
          masterchef: masterchef,
          pool_id: pool_id,
          cake_per_year: Integer.to_string(yearly_emission(pool, blocks_per_year))
        })

      {:ok, maybe_add_apr(output, input)}
    else
      {:error, reason} -> {:error, PancakeSwap.format_error(reason)}
    end
  end

  defp validate_pool_id(pool_id) when is_integer(pool_id) and pool_id >= 0, do: {:ok, pool_id}
  defp validate_pool_id(_), do: {:error, "pool_id must be a non-negative integer"}

  defp read_pool(chain, masterchef, pool_id, opts) do
    call = fn signature, args, outputs ->
      Client.eth_call(chain, masterchef, signature, args, outputs, opts)
    end

    with {:ok, [pool_length]} <- call.("poolLength()", [], ["uint256"]),
         :ok <- check_pool_id(pool_id, pool_length),
         {:ok, [lp_token]} <- call.("lpToken(uint256)", [pool_id], ["address"]),
         {:ok, [_acc_per_share, _last_block, alloc_point, boosted_share, is_regular]} <-
           call.(
             "poolInfo(uint256)",
             [pool_id],
             ["uint256", "uint256", "uint256", "uint256", "bool"]
           ),
         {:ok, [total_alloc_point]} <-
           call.(total_alloc_signature(is_regular), [], ["uint256"]),
         {:ok, [cake_per_block]} <- call.("cakePerBlock(bool)", [is_regular], ["uint256"]) do
      {:ok,
       %{
         pool_length: pool_length,
         lp_token: lp_token,
         is_regular: is_regular,
         alloc_point: alloc_point,
         total_alloc_point: total_alloc_point,
         total_boosted_share: Integer.to_string(boosted_share),
         cake_per_block: Integer.to_string(cake_per_block)
       }}
    end
  end

  defp total_alloc_signature(true), do: "totalRegularAllocPoint()"
  defp total_alloc_signature(false), do: "totalSpecialAllocPoint()"

  defp check_pool_id(pool_id, pool_length) when pool_id < pool_length, do: :ok

  defp check_pool_id(pool_id, pool_length),
    do: {:error, "pool_id #{pool_id} does not exist (pool length is #{pool_length})"}

  defp yearly_emission(%{total_alloc_point: 0}, _blocks_per_year), do: 0

  defp yearly_emission(pool, blocks_per_year) do
    div(
      String.to_integer(pool.cake_per_block) * pool.alloc_point * blocks_per_year,
      pool.total_alloc_point
    )
  end

  defp maybe_add_apr(output, input) do
    cake_price = PancakeSwap.field(input, :cake_price_usd)
    tvl = PancakeSwap.field(input, :pool_tvl_usd)

    if is_number(cake_price) and cake_price > 0 and is_number(tvl) and tvl > 0 do
      yearly_cake = String.to_integer(output.cake_per_year) / @wei_per_token
      Map.put(output, :apr, yearly_cake * cake_price / tvl)
    else
      output
    end
  end
end
