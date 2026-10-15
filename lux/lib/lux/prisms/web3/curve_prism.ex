defmodule Lux.Prisms.Web3.CurvePrism do
  @moduledoc """
  A Prism for Curve Finance stablecoin pool management, swap routing, liquidity provision,
  gauge staking, CRV reward optimization, and peg health monitoring.

  Supported actions:
  - `"list_pools"`: Lists available Curve StableSwap and CryptoSwap pools
  - `"get_pool"`: Retrieves pool reserves, amplification parameter `A`, and APYs
  - `"get_dy"`: Quotes expected output (`dy`) and price impact for a pool swap
  - `"find_best_route"`: Finds optimal swap route across Curve pools
  - `"execute_swap"`: Executes a slippage-protected swap on a Curve pool
  - `"add_liquidity"`: Deposits tokens and mints Curve LP tokens
  - `"remove_liquidity"`: Burns LP tokens for balanced or single-coin withdrawal
  - `"stake_in_gauge"`: Stakes LP tokens into a Curve gauge with `veCRV` boost calculation
  - `"unstake_from_gauge"`: Unstakes LP tokens from a Curve gauge
  - `"claim_rewards"`: Claims CRV rewards with optional auto-compounding
  - `"analyze_peg_health"`: Evaluates stablecoin reserve ratios and depeg alerts
  - `"optimize_yield"`: Generates automated rebalancing recommendations
  """

  use Lux.Prism,
    name: "Curve Finance Prism",
    description:
      "Manages Curve Finance stablecoin pools, optimal routing, gauge staking, and peg health",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Curve operation to perform"
        },
        pool_id: %{
          type: :string,
          description: "Curve pool identifier (e.g. 3pool, frax_usdc, crvusd_usdc, tricrypto2)"
        },
        from_coin: %{
          type: :string,
          description: "Input token symbol (e.g. USDC)"
        },
        to_coin: %{
          type: :string,
          description: "Output token symbol (e.g. USDT)"
        },
        dx: %{
          type: :number,
          description: "Amount of input token to swap"
        },
        min_dy: %{
          type: :number,
          description: "Minimum acceptable output token amount"
        },
        amounts: %{
          type: :array,
          description: "Token amounts corresponding to pool coins for add_liquidity"
        },
        lp_amount: %{
          type: :number,
          description: "LP token amount to burn, stake, or unstake"
        },
        wallet: %{
          type: :string,
          description: "Ethereum wallet address"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Web3.Exchanges.Curve

  @doc """
  Executes the requested Curve Finance action.
  """
  def handler(input, _ctx) do
    action = fetch_param(input, :action)
    dispatch(action, input)
  end

  defp dispatch("list_pools", input) do
    opts =
      []
      |> maybe_put_opt(:pool_type, normalize_optional_atom(fetch_param(input, :pool_type)))
      |> maybe_put_opt(:coin, fetch_param(input, :coin))

    {:ok, pools} = Curve.list_pools(opts)
    {:ok, %{status: "ok", data: %{pools: pools}}}
  end

  defp dispatch("get_pool", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")

    case Curve.get_pool(pool_id) do
      {:ok, pool} -> {:ok, %{status: "ok", data: pool}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("get_dy", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    from_coin = fetch_param(input, :from_coin, "USDC")
    to_coin = fetch_param(input, :to_coin, "USDT")
    dx = fetch_param(input, :dx, 0)

    case Curve.get_dy(pool_id, from_coin, to_coin, dx) do
      {:ok, quote_data} -> {:ok, %{status: "ok", data: quote_data}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("find_best_route", input) do
    from_coin = fetch_param(input, :from_coin, "USDC")
    to_coin = fetch_param(input, :to_coin, "USDT")
    dx = fetch_param(input, :dx, 0)
    max_slippage_bps = fetch_param(input, :max_slippage_bps, 50)

    case Curve.find_best_route(from_coin, to_coin, dx, max_slippage_bps: max_slippage_bps) do
      {:ok, route} -> {:ok, %{status: "ok", data: route}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("execute_swap", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    from_coin = fetch_param(input, :from_coin, "USDC")
    to_coin = fetch_param(input, :to_coin, "USDT")
    dx = fetch_param(input, :dx, 0)
    min_dy = fetch_param(input, :min_dy, 0.0)
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")

    case Curve.execute_swap(pool_id, from_coin, to_coin, dx, min_dy, wallet: wallet) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("add_liquidity", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    amounts = fetch_param(input, :amounts, [])
    min_mint = fetch_param(input, :min_mint_amount, 0.0)
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")

    case Curve.add_liquidity(pool_id, amounts, min_mint, wallet: wallet) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("remove_liquidity", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    lp_amount = fetch_param(input, :lp_amount, 0.0)
    one_coin = fetch_param(input, :one_coin)
    mode = if is_binary(one_coin), do: {:one_coin, one_coin}, else: :balanced
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")

    case Curve.remove_liquidity(pool_id, lp_amount, mode, wallet: wallet) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("stake_in_gauge", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    lp_amount = fetch_param(input, :lp_amount, 0.0)
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")
    vecrv = fetch_param(input, :vecrv_balance, 0.0)

    case Curve.stake_in_gauge(pool_id, lp_amount, wallet: wallet, vecrv_balance: vecrv) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("unstake_from_gauge", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    lp_amount = fetch_param(input, :lp_amount, 0.0)
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")

    case Curve.unstake_from_gauge(pool_id, lp_amount, wallet: wallet) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("claim_rewards", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")
    compound = fetch_param(input, :compound, false)
    days = fetch_param(input, :days_elapsed, 7)

    case Curve.claim_rewards(pool_id, wallet: wallet, compound: compound, days_elapsed: days) do
      {:ok, receipt} -> {:ok, %{status: "ok", data: receipt}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("analyze_peg_health", input) do
    pool_id = fetch_param(input, :pool_id, "3pool")

    case Curve.analyze_peg_health(pool_id) do
      {:ok, report} -> {:ok, %{status: "ok", data: report}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp dispatch("optimize_yield", input) do
    wallet = fetch_param(input, :wallet, "0x0000000000000000000000000000000000000001")
    vecrv = fetch_param(input, :vecrv_balance, 25_000.0)
    {:ok, plan} = Curve.optimize_yield_rebalance(wallet, vecrv_balance: vecrv)
    {:ok, %{status: "ok", data: plan}}
  end

  defp dispatch(_unknown, _input), do: {:error, :unsupported_action}

  defp fetch_param(map, key, default \\ nil) when is_map(map) and is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, key, val), do: Keyword.put(opts, key, val)

  defp normalize_optional_atom(nil), do: nil
  defp normalize_optional_atom(val) when is_atom(val), do: val
  defp normalize_optional_atom(val) when is_binary(val), do: String.to_atom(val)
end
