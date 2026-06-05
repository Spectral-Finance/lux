defmodule Lux.Integrations.Curve do
  @moduledoc """
  Curve Finance integration — provides stablecoin pool analytics,
  swap calculations, and liquidity management.

  Supports:
  - Pool queries and analytics
  - Stablecoin swap calculations (constant product + amplified pools)
  - Pool APY estimation
  - Stablecoin pool management helpers
  """

  @base_url "https://api.curve.fi/api"

  # ── Pool Queries ──────────────────────────────────────────────────────────

  @doc """
  Gets all pools from the Curve API.
  """
  def get_pools(blockchain \\ "ethereum") do
    url = "#{@base_url}/getPools/#{blockchain}"

    case get_request(url) do
      {:ok, %{"data" => {"poolData" => pool_data}}} when is_list(pool_data) ->
        {:ok, Enum.map(pool_data, &format_pool/1)}

      {:ok, %{"data" => data}} ->
        {:ok, format_pool_list(data)}

      {:ok, %{"success" => false, "errors" => errors}} ->
        {:error, errors}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  @doc """
  Gets detailed information about a specific pool.
  """
  def get_pool(pool_id, blockchain \\ "ethereum") do
    url = "#{@base_url}/getPool/#{blockchain}/#{pool_id}"

    case get_request(url) do
      {:ok, %{"data" => data}} ->
        {:ok, format_pool_detail(data)}

      {:ok, %{"success" => false, "errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  @doc """
  Gets pool factory information.
  """
  def get_factory_pools(blockchain \\ "ethereum") do
    url = "#{@base_url}/getFactoryPools/#{blockchain}"

    case get_request(url) do
      {:ok, %{"data" => data}} ->
        pools = extract_pools_from_data(data)
        {:ok, Enum.map(pools, &format_factory_pool/1)}

      error ->
        error
    end
  end

  # ── Pool Analytics ────────────────────────────────────────────────────────

  @doc """
  Computes analytics for a given pool.
  """
  def analyze_pool(pool_id, opts \\ []) do
    blockchain = Keyword.get(opts, :blockchain, "ethereum")

    with {:ok, pool} <- get_pool(pool_id, blockchain) do
      total_liquidity = Map.get(pool, :total_liquidity, 0)
      volume_24h = Map.get(pool, :volume_24h, 0)
      fee_rate = Map.get(pool, :fee, 0.0004)

      daily_fees = volume_24h * fee_rate
      annual_fees = daily_fees * 365
      apy = if total_liquidity > 0, do: annual_fees / total_liquidity * 100, else: 0

      virtual_price = Map.get(pool, :virtual_price, 1.0)
      amplification = Map.get(pool, :a_coefficient, 0)
      n_coins = Map.get(pool, :n_coins, 0)

      {:ok, %{
        pool_id: pool_id,
        pool_name: Map.get(pool, :name),
        total_liquidity_usd: total_liquidity,
        volume_24h_usd: volume_24h,
        daily_fees_usd: daily_fees,
        annual_fees_usd: annual_fees,
        apy: Float.round(apy, 2),
        virtual_price: virtual_price,
        amplification_coefficient: amplification,
        n_coins: n_coins,
        fee_rate: fee_rate,
        utilization_rate: calculate_utilization_rate(pool),
        pool_type: Map.get(pool, :pool_type)
      }}
    end
  end

  @doc """
  Gets historical APY data for a pool.
  """
  def get_pool_apy_history(pool_id, days \\ 30, opts \\ []) do
    blockchain = Keyword.get(opts, :blockchain, "ethereum")

    url = "#{@base_url}/getPoolAPY/#{blockchain}/#{pool_id}"

    case get_request(url) do
      {:ok, %{"data" => apy_data}} ->
        formatted = format_apy_data(apy_data)
        # Truncate to requested days
        truncated = Enum.take(formatted, days)

        {:ok, %{
          pool_id: pool_id,
          days: min(length(truncated), days),
          apy_data: truncated,
          average_apy: calculate_average_apy(truncated)
        }}

      error ->
        error
    end
  end

  @doc """
  Gets the utilization rate for a pool's liquidity.
  """
  def get_utilization_rate(pool_id, opts \\ []) do
    blockchain = Keyword.get(opts, :blockchain, "ethereum")

    with {:ok, pool} <- get_pool(pool_id, blockchain) do
      rate = calculate_utilization_rate(pool)

      {:ok, %{
        pool_id: pool_id,
        utilization_rate: rate,
        status: classify_utilization(rate)
      }}
    end
  end

  # ── Stablecoin Swap Calculations ──────────────────────────────────────────

  @doc """
  Calculates the expected output of a stablecoin swap.
  Uses the Curve stable swap invariant: D = n^n * A * sum(x_i) + D^(n+1) / (n^n * prod(x_i))
  """
  def calculate_swap(pool_id, token_in, token_out, amount, opts \\ []) do
    blockchain = Keyword.get(opts, :blockchain, "ethereum")

    with {:ok, pool} <- get_pool(pool_id, blockchain),
         balances = Map.get(pool, :balances, []),
         a_coeff = Map.get(pool, :a_coefficient, 100),
         n_coins = Map.get(pool, :n_coins, length(balances)),
         fee = Map.get(pool, :fee, 0.0004) do
      # Find indices
      in_idx = find_token_index(pool, token_in)
      out_idx = find_token_index(pool, token_out)

      if in_idx == nil or out_idx == nil do
        {:error, "Token not found in pool"}
      else
        # Calculate using Curve stable swap formula
        d = compute_d(balances, a_coeff, n_coins)
        new_balances = update_balance(balances, in_idx, amount)
        new_d = compute_d(new_balances, a_coeff, n_coins)

        # Calculate output
        out_amount = calculate_y(new_balances, out_idx, new_d, a_coeff, n_coins)
        fee_amount = out_amount * fee
        final_amount = out_amount - fee_amount

        # Price impact
        price_impact = if amount > 0, do: ((out_amount - final_amount) / out_amount) * 100, else: 0

        {:ok, %{
          pool_id: pool_id,
          token_in: token_in,
          token_out: token_out,
          amount_in: amount,
          expected_output: final_amount,
          fee_paid: fee_amount,
          price_impact_pct: Float.round(price_impact, 4),
          exchange_rate: if(final_amount > 0, do: final_amount / amount, else: 0),
          pool_liquidity: Enum.sum(balances)
        }}
      end
    end
  end

  @doc """
  Calculates the optimal swap amount to minimize price impact.
  """
  def calculate_optimal_swap(pool_id, token_in, token_out, opts \\ []) do
    max_slippage = Keyword.get(opts, :max_slippage, 0.01)
    blockchain = Keyword.get(opts, :blockchain, "ethereum")

    with {:ok, pool} <- get_pool(pool_id, blockchain),
         balances = Map.get(pool, :balances, []) do
      pool_liquidity = Enum.sum(balances)
      # Optimal is typically ~5-10% of pool liquidity to keep slippage low
      optimal = pool_liquidity * 0.05

      # Verify with actual calculation
      case calculate_swap(pool_id, token_in, token_out, optimal, blockchain: blockchain) do
        {:ok, result} ->
          if result.price_impact_pct <= max_slippage * 100 do
            {:ok, result}
          else
            # Binary search for amount that keeps impact under slippage
            find_amount_within_slippage(pool_id, token_in, token_out, 0, optimal, max_slippage * 100, blockchain)
          end

        error ->
          error
      end
    end
  end

  @doc """
  Estimates the slippage for a given swap amount.
  """
  def estimate_slippage(pool_id, token_in, token_out, amount, opts \\ []) do
    case calculate_swap(pool_id, token_in, token_out, amount, opts) do
      {:ok, result} -> {:ok, result.price_impact_pct}
      error -> error
    end
  end

  # ── Stablecoin Pool Management ───────────────────────────────────────────

  @doc """
  Gets the optimal pool for swapping between two stablecoins.
  """
  def find_best_pool_for_swap(token_in, token_out, amount, opts \\ []) do
    blockchains = Keyword.get(opts, :blockchains, ["ethereum"])

    results =
      blockchains
      |> Enum.flat_map(fn blockchain ->
        case get_pools(blockchain) do
          {:ok, pools} ->
            pools
            |> Enum.filter(fn p -> pool_has_tokens?(p, [token_in, token_out]) end)
            |> Enum.map(fn pool ->
              case calculate_swap(pool.id, token_in, token_out, amount, blockchain: blockchain) do
                {:ok, result} -> {pool.name, result}
                _ -> nil
              end
            end)
            |> Enum.reject(&is_nil/1)

          _ ->
            []
        end
      end)
      |> Enum.sort_by(fn {_name, result} -> result.price_impact_pct end)

    case results do
      [] -> {:error, "No suitable pool found for #{token_in} -> #{token_out}"}
      pools -> {:ok, %{token_in: token_in, token_out: token_out, amount: amount, best_pools: pools}}
    end
  end

  @doc """
  Computes the D invariant for the Curve stable swap formula.
  D = n^n * A * sum(x_i) + D^(n+1) / (n^n * prod(x_i))
  """
  def compute_d(balances, a_coeff, n_coins) do
    sum = Enum.sum(balances)

    if sum == 0 do
      0
    else
      ann = a_coeff * n_coins
      d = sum

      # Newton's method iteration
      iterate_d(d, balances, ann, n_coins, 100)
    end
  end

  @doc """
  Calculates y (output amount) given new balances and D.
  """
  def calculate_y(balances, out_idx, d, a_coeff, n_coins) do
    ann = a_coeff * n_coins
    sum_minus_y = balances |> List.delete_at(out_idx) |> Enum.sum()

    # Newton's method for y
    iterate_y(d, sum_minus_y, ann, n_coins, d, 100)
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp get_request(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Request failed: #{Exception.message(e)}"}
  end

  defp format_pool(pool) do
    %{
      id: Map.get(pool, "id") || Map.get(pool, "address"),
      name: Map.get(pool, "name") || Map.get(pool, "pool"),
      address: Map.get(pool, "address"),
      pool_type: Map.get(pool, "poolType") || Map.get(pool, "type"),
      n_coins: parse_int(Map.get(pool, "nCoins") || Map.get(pool, "n_coins")),
      a_coefficient: parse_float(Map.get(pool, "A") || Map.get(pool, "a_coefficient") || 100),
      fee: parse_float(Map.get(pool, "fee") || 0.0004),
      virtual_price: parse_float(Map.get(pool, "virtualPrice") || 1.0),
      total_liquidity: parse_float(Map.get(pool, "totalLiquidity") || Map.get(pool, "tvl") || 0),
      volume_24h: parse_float(Map.get(pool, "volume24h") || Map.get(pool, "volume") || 0),
      balances: Map.get(pool, "balances", []) |> Enum.map(&parse_float/1),
      coins: Map.get(pool, "coins", []) || Map.get(pool, "tokens", [])
    }
  end

  defp format_pool_detail(data) do
    format_pool(data)
  end

  defp format_pool_list(data) when is_map(data) do
    # Try different key formats
    pools = extract_pools_from_data(data)
    Enum.map(pools, &format_pool/1)
  end

  defp format_factory_pool(pool) do
    format_pool(pool)
    |> Map.put(:factory, true)
  end

  defp format_apy_data(data) when is_list(data) do
    data
    |> Enum.map(fn day ->
      %{
        date: Map.get(day, "date") || Map.get(day, "timestamp"),
        apy: parse_float(Map.get(day, "apy") || Map.get(day, "daily_apy") || 0)
      }
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp format_apy_data(data) when is_map(data) do
    data
    |> Map.to_list()
    |> Enum.map(fn {date, apy} ->
      %{date: date, apy: parse_float(apy)}
    end)
    |> Enum.sort_by(& &1.date)
  end

  defp format_apy_data(_), do: []

  defp extract_pools_from_data(data) do
    cond do
      is_list(data) -> data
      Map.has_key?(data, "poolData") -> Map.get(data, "poolData", [])
      Map.has_key?(data, "pools") -> Map.get(data, "pools", [])
      Map.has_key?(data, "data") -> Map.get(data, "data", []) |> extract_pools_from_data()
      true -> []
    end
  end

  defp calculate_utilization_rate(pool) do
    balances = Map.get(pool, :balances, [])
    total_liquidity = Map.get(pool, :total_liquidity, 0)

    if total_liquidity > 0 and length(balances) > 0 do
      # Utilization = (total_liquidity - idle_balance) / total_liquidity
      # Where idle balance = min of all token balances (assumes balanced pool)
      min_balance = Enum.min(balances)
      used_liquidity = total_liquidity - min_balance
      Float.round(max(0, used_liquidity / total_liquidity), 4)
    else
      0.0
    end
  end

  defp classify_utilization(rate) when rate < 0.3, do: :underutilized
  defp classify_utilization(rate) when rate < 0.6, do: :moderate
  defp classify_utilization(rate) when rate < 0.85, do: :efficient
  defp classify_utilization(_rate), do: :highly_utilized

  defp calculate_average_apy(apy_data) do
    apys = Enum.map(apy_data, & &1.apy)
    if apys == [] do
      0.0
    else
      Float.round(Enum.sum(apys) / length(apys), 2)
    end
  end

  defp find_token_index(pool, token_address) do
    coins = Map.get(pool, :coins, [])

    Enum.find_index(coins, fn coin ->
      case coin do
        %{"id" => id} -> id == token_address
        %{"address" => addr} -> addr == token_address
        addr when is_binary(addr) -> addr == token_address
        _ -> false
      end
    end)
  end

  defp pool_has_tokens?(pool, tokens) do
    coins = Map.get(pool, :coins, [])
    coin_ids = Enum.map(coins, fn
      %{"id" => id} -> id
      %{"address" => addr} -> addr
      addr when is_binary(addr) -> addr
      _ -> nil
    end)

    Enum.all?(tokens, fn token -> token in coin_ids end)
  end

  defp update_balance(balances, idx, amount) do
    List.update_at(balances, idx, &(&1 + amount))
  end

  defp iterate_d(d, balances, ann, n, iterations) when iterations > 0 do
    sum = Enum.sum(balances)
    product = Enum.reduce(balances, d, &(&2 * &1 / (n * d)))

    d_new = ((ann * sum + n * product) * d) / ((ann - 1) * d + (n + 1) * product)

    if abs(d_new - d) < 1 do
      d_new
    else
      iterate_d(d_new, balances, ann, n, iterations - 1)
    end
  end

  defp iterate_d(d, _balances, _ann, _n, 0), do: d

  defp iterate_y(y, sum_minus_y, ann, n, d, iterations) when iterations > 0 do
    product = :math.pow(y, n - 1) * :math.pow(d / (n * ann), n)
    y_new = (:math.pow(d, n + 1) / (n * n * ann * product) + sum_minus_y - d) / -1

    if abs(y_new - y) < 1 do
      y_new
    else
      iterate_y(y_new, sum_minus_y, ann, n, d, iterations - 1)
    end
  end

  defp iterate_y(y, _sum, _ann, _n, _d, 0), do: y

  defp find_amount_within_slippage(pool_id, token_in, token_out, low, high, max_impact, blockchain) do
    mid = (low + high) / 2

    if high - low < 1 do
      case calculate_swap(pool_id, token_in, token_out, low, blockchain: blockchain) do
        {:ok, result} -> {:ok, result}
        error -> error
      end
    else
      case calculate_swap(pool_id, token_in, token_out, mid, blockchain: blockchain) do
        {:ok, result} ->
          if result.price_impact_pct <= max_impact do
            find_amount_within_slippage(pool_id, token_in, token_out, mid, high, max_impact, blockchain)
          else
            find_amount_within_slippage(pool_id, token_in, token_out, low, mid, max_impact, blockchain)
          end

        error ->
          error
      end
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_number(val), do: val / 1
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_int(nil), do: 0
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end
