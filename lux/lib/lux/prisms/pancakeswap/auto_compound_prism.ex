defmodule Lux.Prisms.PancakeSwap.AutoCompoundPrism do
  @moduledoc """
  Plans an auto-compound cycle for a MasterChef V2 farm position.

  The prism first decides whether compounding is worth it: the pending CAKE reward (in
  USD) must be at least `min_profit_ratio` times the gas cost of the whole cycle
  (`gas_cost_usd`). When it is not, it returns `should_compound: false` with no steps.

  Otherwise it reads the pool's LP pair from chain and returns the ordered, *unsigned*
  steps of one cycle:

    1. `harvest` - `deposit(pid, 0)` collects the pending CAKE
    2. `approve` CAKE for the router (if needed)
    3. `swap` half of the CAKE into each pair token (a side that already is CAKE is not
       swapped), using `getAmountsOut` quotes and `slippage_bps`
    4. `approve` the pair tokens for the router (if needed)
    5. `add_liquidity` with the guaranteed (slippage adjusted) swap outputs
    6. `approve` the LP token for the MasterChef (if needed)
    7. `deposit` the estimated LP amount back into the farm

  Because the exact LP amount minted is only known after the previous steps execute, the
  deposited amount is estimated from the pair reserves and total supply and reduced by
  `slippage_bps`; a small dust amount of LP may stay in the wallet. Swap paths default to
  `[CAKE, token]`; pass `path_token0` / `path_token1` (address lists) to route through
  another token such as WBNB.

  ## Example

      iex> Lux.Prisms.PancakeSwap.AutoCompoundPrism.run(%{
      ...>   chain: "bsc",
      ...>   pool_id: 2,
      ...>   owner: "0x00000000000000000000000000000000000000aa",
      ...>   cake_price_usd: 2.5,
      ...>   gas_cost_usd: 0.6
      ...> })
      {:ok, %{should_compound: true, steps: [%{name: "harvest", ...}, ...]}}
  """

  use Lux.Prism,
    name: "PancakeSwap Auto Compound",
    description:
      "Decides whether to compound a farm position and builds the unsigned harvest, swap, add liquidity and restake steps",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string, description: "Chain name or id (default: bsc)", default: "bsc"},
        pool_id: %{type: :integer, minimum: 0, description: "MasterChef pool id (pid)"},
        owner: %{
          type: :string,
          description: "Wallet address that owns the position",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        pending_cake: %{
          type: [:string, :integer],
          description: "Pending CAKE in wei (read from chain if omitted)"
        },
        cake_price_usd: %{type: :number, description: "CAKE price in USD"},
        gas_cost_usd: %{
          type: :number,
          description: "Estimated gas cost of the whole cycle in USD"
        },
        min_profit_ratio: %{
          type: :number,
          description: "Reward must be at least this multiple of the gas cost",
          default: 3
        },
        slippage_bps: %{type: :integer, minimum: 0, maximum: 10_000, default: 50},
        path_token0: %{
          type: :array,
          items: %{type: :string},
          description: "Swap path CAKE -> token0"
        },
        path_token1: %{
          type: :array,
          items: %{type: :string},
          description: "Swap path CAKE -> token1"
        },
        deadline: %{type: :integer, description: "Unix deadline (default: now + 20 minutes)"},
        masterchef: %{type: :string, description: "Override the MasterChef address"},
        router: %{type: :string, description: "Override the router address"},
        rpc_url: %{type: :string, description: "Override the JSON-RPC endpoint"}
      },
      required: ["pool_id", "owner", "cake_price_usd", "gas_cost_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :string},
        chain_id: %{type: :integer},
        pool_id: %{type: :integer},
        should_compound: %{type: :boolean},
        reason: %{type: :string},
        pending_cake: %{type: :string},
        reward_usd: %{type: :number},
        gas_cost_usd: %{type: :number},
        min_profit_ratio: %{type: :number},
        lp_token: %{type: :string},
        estimated_lp: %{type: :string},
        steps: %{type: :array}
      },
      required: ["chain", "pool_id", "should_compound", "steps"]
    }

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Lux.Integrations.PancakeSwap.Transactions

  @wei_per_token 1.0e18
  @default_min_profit_ratio 3

  def handler(input, _ctx) do
    with {:ok, ctx} <- build_context(input),
         {:ok, pending} <- pending_cake(ctx, input) do
      reward_usd = pending / @wei_per_token * ctx.cake_price_usd
      summary = summary(ctx, pending, reward_usd)

      case decide(pending, reward_usd, ctx) do
        {:skip, reason} ->
          {:ok, Map.merge(summary, %{should_compound: false, reason: reason, steps: []})}

        :compound ->
          with {:ok, plan} <- Transactions.safe(fn -> build_plan(ctx, pending, input) end) do
            {:ok,
             Map.merge(summary, %{
               should_compound: true,
               reason: "Pending reward covers the estimated gas cost",
               lp_token: plan.lp_token,
               estimated_lp: Integer.to_string(plan.estimated_lp),
               steps: plan.steps
             })}
          end
      end
    end
    |> normalize_error()
  end

  defp normalize_error({:error, reason}), do: {:error, PancakeSwap.format_error(reason)}
  defp normalize_error(ok), do: ok

  defp build_context(input) do
    owner = PancakeSwap.field(input, :owner)
    pool_id = PancakeSwap.field(input, :pool_id)
    cake_price = PancakeSwap.field(input, :cake_price_usd)
    gas_cost = PancakeSwap.field(input, :gas_cost_usd)
    ratio = PancakeSwap.field(input, :min_profit_ratio, @default_min_profit_ratio)

    with {:ok, chain} <- PancakeSwap.fetch_chain(PancakeSwap.field(input, :chain, "bsc")),
         :ok <- validate_pool_id(pool_id),
         :ok <- validate_owner(owner),
         :ok <- validate_number(:cake_price_usd, cake_price, :positive),
         :ok <- validate_number(:gas_cost_usd, gas_cost, :non_negative),
         :ok <- validate_number(:min_profit_ratio, ratio, :non_negative),
         {:ok, slippage_bps} <-
           PancakeSwap.parse_slippage(PancakeSwap.field(input, :slippage_bps)),
         {:ok, masterchef} <-
           PancakeSwap.address(chain, :masterchef_v2, PancakeSwap.field(input, :masterchef)),
         {:ok, router} <-
           PancakeSwap.address(chain, :router_v2, PancakeSwap.field(input, :router)),
         {:ok, cake} <- PancakeSwap.address(chain, :cake) do
      {:ok,
       %{
         chain: chain,
         pool_id: pool_id,
         owner: owner,
         cake_price_usd: cake_price,
         gas_cost_usd: gas_cost,
         min_profit_ratio: ratio,
         slippage_bps: slippage_bps,
         masterchef: masterchef,
         router: router,
         cake: cake,
         deadline: PancakeSwap.deadline(input),
         opts: PancakeSwap.rpc_opts(input)
       }}
    end
  end

  defp validate_pool_id(pool_id) when is_integer(pool_id) and pool_id >= 0, do: :ok
  defp validate_pool_id(_), do: {:error, "pool_id must be a non-negative integer"}

  defp validate_owner(owner) do
    if PancakeSwap.valid_address?(owner),
      do: :ok,
      else: {:error, "owner must be a valid 0x-prefixed Ethereum address"}
  end

  defp validate_number(_name, value, :positive) when is_number(value) and value > 0, do: :ok
  defp validate_number(_name, value, :non_negative) when is_number(value) and value >= 0, do: :ok

  defp validate_number(name, _value, :positive), do: {:error, "#{name} must be a positive number"}

  defp validate_number(name, _value, :non_negative),
    do: {:error, "#{name} must be a non-negative number"}

  defp pending_cake(ctx, input) do
    case PancakeSwap.field(input, :pending_cake) do
      nil ->
        signature = "pendingCake(uint256,address)"

        case call(ctx, "pending CAKE", ctx.masterchef, signature, [ctx.pool_id, ctx.owner], [
               "uint256"
             ]) do
          {:ok, [pending]} -> {:ok, pending}
          {:error, _} = error -> error
        end

      value ->
        case PancakeSwap.parse_amount(value) do
          {:ok, pending} -> {:ok, pending}
          :error -> {:error, "pending_cake must be a non-negative integer (wei)"}
        end
    end
  end

  defp summary(ctx, pending, reward_usd) do
    %{
      chain: ctx.chain.name,
      chain_id: ctx.chain.id,
      pool_id: ctx.pool_id,
      pending_cake: Integer.to_string(pending),
      reward_usd: reward_usd,
      gas_cost_usd: ctx.gas_cost_usd,
      min_profit_ratio: ctx.min_profit_ratio
    }
  end

  defp decide(0, _reward_usd, _ctx), do: {:skip, "No pending CAKE to compound"}

  defp decide(_pending, reward_usd, ctx) do
    required = ctx.gas_cost_usd * ctx.min_profit_ratio

    if reward_usd >= required do
      :compound
    else
      {:skip,
       "Pending reward ($#{Float.round(reward_usd * 1.0, 4)}) is below #{ctx.min_profit_ratio}x the gas cost ($#{ctx.gas_cost_usd})"}
    end
  end

  defp build_plan(ctx, pending, input) do
    with {:ok, pair} <- pair_info(ctx),
         {:ok, swaps} <- plan_swaps(ctx, pending, pair, input),
         {:ok, estimated_lp} <- estimate_lp(ctx, pair, swaps),
         {:ok, steps} <- assemble_steps(ctx, pending, pair, swaps, estimated_lp) do
      {:ok,
       %{lp_token: pair.address, estimated_lp: deposit_amount(ctx, estimated_lp), steps: steps}}
    end
  end

  defp pair_info(ctx) do
    with {:ok, [pair]} <-
           call(ctx, "LP token", ctx.masterchef, "lpToken(uint256)", [ctx.pool_id], ["address"]),
         {:ok, [token0]} <- call(ctx, "pair token0", pair, "token0()", [], ["address"]),
         {:ok, [token1]} <- call(ctx, "pair token1", pair, "token1()", [], ["address"]) do
      {:ok, %{address: pair, token0: token0, token1: token1}}
    end
  end

  # Returns [%{token, side, cake_in, amount, swap?, path}] for token0 and token1.
  defp plan_swaps(ctx, pending, pair, input) do
    half = div(pending, 2)
    portions = [{:token0, pair.token0, half}, {:token1, pair.token1, pending - half}]

    Enum.reduce_while(portions, {:ok, []}, fn {side, token, cake_in}, {:ok, acc} ->
      case plan_swap(ctx, side, token, cake_in, input) do
        {:ok, swap} -> {:cont, {:ok, acc ++ [swap]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp plan_swap(ctx, side, token, cake_in, input) do
    if same_address?(token, ctx.cake) do
      {:ok,
       %{side: side, token: token, cake_in: cake_in, swap?: false, amount: cake_in, path: []}}
    else
      with {:ok, path} <- swap_path(ctx, side, token, input),
           {:ok, [amounts]} <-
             call(
               ctx,
               "swap quote for #{side}",
               ctx.router,
               "getAmountsOut(uint256,address[])",
               [cake_in, path],
               ["uint256[]"]
             ) do
        min_out = PancakeSwap.apply_slippage(List.last(amounts), ctx.slippage_bps)

        {:ok,
         %{side: side, token: token, cake_in: cake_in, swap?: true, amount: min_out, path: path}}
      end
    end
  end

  defp swap_path(ctx, side, token, input) do
    case PancakeSwap.field(input, :"path_#{side}") do
      nil ->
        {:ok, [ctx.cake, token]}

      path when is_list(path) and length(path) >= 2 ->
        if Enum.all?(path, &PancakeSwap.valid_address?/1) and
             same_address?(hd(path), ctx.cake) and
             same_address?(List.last(path), token) do
          {:ok, path}
        else
          {:error, "path_#{side} must be a list of addresses from CAKE to #{token}"}
        end

      _ ->
        {:error, "path_#{side} must be a list of at least two addresses"}
    end
  end

  defp estimate_lp(ctx, pair, swaps) do
    with {:ok, [reserve0, reserve1, _timestamp]} <-
           call(ctx, "pair reserves", pair.address, "getReserves()", [], [
             "uint112",
             "uint112",
             "uint32"
           ]),
         {:ok, [total_supply]} <-
           call(ctx, "LP total supply", pair.address, "totalSupply()", [], ["uint256"]) do
      [amount0, amount1] = Enum.map(swaps, & &1.amount)

      if reserve0 == 0 or reserve1 == 0 do
        {:error, "The pair has no liquidity, cannot estimate the LP amount"}
      else
        {:ok, min(div(amount0 * total_supply, reserve0), div(amount1 * total_supply, reserve1))}
      end
    end
  end

  defp deposit_amount(ctx, estimated_lp),
    do: PancakeSwap.apply_slippage(estimated_lp, ctx.slippage_bps)

  defp assemble_steps(ctx, pending, pair, swaps, estimated_lp) do
    chain = ctx.chain
    [swap0, swap1] = swaps
    lp_deposit = deposit_amount(ctx, estimated_lp)

    if lp_deposit == 0 do
      {:error, "Estimated LP amount is zero, the reward is too small to compound"}
    else
      harvest =
        Transactions.step("harvest", chain, ctx.masterchef, "deposit(uint256,uint256)", [
          ctx.pool_id,
          0
        ])

      with {:ok, cake_approval} <-
             Transactions.approval_steps(
               chain,
               ctx.cake,
               ctx.owner,
               ctx.router,
               pending,
               ctx.opts
             ),
           {:ok, token_approvals} <- token_approvals(ctx, [swap0, swap1]),
           {:ok, lp_approval} <-
             Transactions.approval_steps(
               chain,
               pair.address,
               ctx.owner,
               ctx.masterchef,
               lp_deposit,
               ctx.opts
             ) do
        swap_steps = for swap <- swaps, swap.swap?, do: swap_step(ctx, swap)

        add_liquidity =
          Transactions.step(
            "add_liquidity",
            chain,
            ctx.router,
            "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
            [
              swap0.token,
              swap1.token,
              swap0.amount,
              swap1.amount,
              PancakeSwap.apply_slippage(swap0.amount, ctx.slippage_bps),
              PancakeSwap.apply_slippage(swap1.amount, ctx.slippage_bps),
              ctx.owner,
              ctx.deadline
            ]
          )

        deposit =
          Transactions.step("deposit", chain, ctx.masterchef, "deposit(uint256,uint256)", [
            ctx.pool_id,
            lp_deposit
          ])

        {:ok,
         [harvest] ++
           cake_approval ++
           swap_steps ++ token_approvals ++ [add_liquidity] ++ lp_approval ++ [deposit]}
      end
    end
  end

  # CAKE is already approved for `pending`; only the swapped-into tokens need approvals.
  defp token_approvals(ctx, swaps) do
    swaps
    |> Enum.filter(& &1.swap?)
    |> Enum.reduce_while({:ok, []}, fn swap, {:ok, acc} ->
      case Transactions.approval_steps(
             ctx.chain,
             swap.token,
             ctx.owner,
             ctx.router,
             swap.amount,
             ctx.opts
           ) do
        {:ok, steps} -> {:cont, {:ok, acc ++ steps}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp swap_step(ctx, swap) do
    Transactions.step(
      "swap_#{swap.side}",
      ctx.chain,
      ctx.router,
      "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
      [swap.cake_in, swap.amount, swap.path, ctx.owner, ctx.deadline]
    )
  end

  defp same_address?(a, b), do: String.downcase(a) == String.downcase(b)

  defp call(ctx, label, to, signature, args, outputs) do
    case Client.eth_call(ctx.chain, to, signature, args, outputs, ctx.opts) do
      {:ok, values} -> {:ok, values}
      {:error, reason} -> {:error, "Failed to read #{label}: #{PancakeSwap.format_error(reason)}"}
    end
  end
end
