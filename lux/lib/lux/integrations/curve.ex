defmodule Lux.Integrations.Curve do
  @moduledoc """
  Integration with Curve Finance for stableswap and liquidity pool operations.

  Curve Finance is a DEX optimized for stablecoins and similar assets,
  providing low-slippage swaps and concentrated liquidity pools.

  ## Configuration

      config :lux, Lux.Integrations.Curve,
        base_url: System.get_env("CURVE_API_URL") || "https://api.curve.fi/v1",
        registry_address: System.get_env("CURVE_REGISTRY") || "0x90E00ACe148ca3b23Ac1bC8C240C2a7Dd9c2d747"

  ## Usage

      # Get pool info
      {:ok, pool} = Curve.get_pool("0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7")

      # Get swap quote
      {:ok, quote} = Curve.get_swap_quote(pool_address, from_coin, to_coin, amount)

      # Get gauge info for yield farming
      {:ok, gauge} = Curve.get_gauge_info(pool_address)
  """

  @base_url Application.get_env(:lux, __MODULE__, [])[:base_url] || "https://api.curve.fi/v1"

  @doc "Common request settings for Curve API"
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{type: :none}
    }
  end

  # ─── Pool Operations ────────────────────────────────────────

  @doc "Get detailed pool information including TVL, APY, and coin composition"
  def get_pool(pool_address) do
    case http_get("/getPool/#{pool_address}") do
      {:ok, %{"data" => data}} -> {:ok, parse_pool(data)}
      {:ok, %{"poolData" => data}} -> {:ok, parse_pool(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "List all pools with optional filtering by asset type"
  def list_pools(opts \\ []) do
    params = build_query_params(opts)
    case http_get("/getPools?#{params}") do
      {:ok, %{"data" => pools}} -> {:ok, Enum.map(pools, &parse_pool/1)}
      {:ok, %{"poolData" => pools}} -> {:ok, Enum.map(pools, &parse_pool/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Get pool TVL and volume stats"
  def get_pool_stats(pool_address) do
    case http_get("/getPoolStats/#{pool_address}") do
      {:ok, %{"data" => data}} -> {:ok, parse_pool_stats(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  # ─── Swap Operations ────────────────────────────────────────

  @doc "Get a swap quote with estimated output and price impact"
  def get_swap_quote(pool_address, from_coin, to_coin, amount) do
    params = "pool=#{pool_address}&from=#{from_coin}&to=#{to_coin}&amount=#{amount}"
    case http_get("/getSwapQuote?#{params}") do
      {:ok, %{"data" => data}} -> {:ok, parse_swap_quote(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Get estimated swap output for a given input"
  def get_swap_output(pool_address, from_coin, to_coin, amount) do
    case get_swap_quote(pool_address, from_coin, to_coin, amount) do
      {:ok, quote} -> {:ok, quote.output_amount}
      {:error, reason} -> {:error, reason}
    end
  end

  # ─── Gauge & Yield Farming ──────────────────────────────────

  @doc "Get gauge information for a pool including rewards and APY"
  def get_gauge_info(pool_address) do
    case http_get("/getGauge/#{pool_address}") do
      {:ok, %{"data" => data}} -> {:ok, parse_gauge(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "List all gauges with their reward information"
  def list_gauges(opts \\ []) do
    params = build_query_params(opts)
    case http_get("/getGauges?#{params}") do
      {:ok, %{"data" => gauges}} -> {:ok, Enum.map(gauges, &parse_gauge/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Get CRV emissions schedule and reward info"
  def get_crv_emissions do
    case http_get("/getCRVEmissions") do
      {:ok, %{"data" => data}} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  # ─── Bridge & Cross-Chain ───────────────────────────────────

  @doc "Get available cross-chain pools and bridge status"
  def get_cross_chain_pools do
    case http_get("/getCrossChainPools") do
      {:ok, %{"data" => pools}} -> {:ok, Enum.map(pools, &parse_pool/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Get bridge status for a specific pool and chain"
  def get_bridge_status(pool_address, chain) do
    case http_get("/getBridgeStatus/#{pool_address}?chain=#{chain}") do
      {:ok, %{"data" => data}} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  # ─── Rate Limiting ──────────────────────────────────────────

  @doc "Returns rate limit configuration for Curve API"
  def rate_limit_info do
    %{public_limit: 30, private_limit: 10, window_seconds: 60}
  end

  # ─── Private Helpers ────────────────────────────────────────

  defp http_get(path) do
    url = @base_url <> path
    headers = [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

    case HTTPoison.get(url, headers, recv_timeout: 15_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_json}
        end
      {:ok, %HTTPoison.Response{status_code: 429}} ->
        {:error, :rate_limited}
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, {:http_error, status}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp build_query_params(opts) do
    opts
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join("&")
  end

  defp parse_pool(data) do
    %{
      address: data["address"] || data["id"] || "",
      name: data["name"] || "",
      coins: data["coins"] || [],
      coin_names: data["coinNames"] || data["coin_names"] || [],
      tvl: parse_float(data["tvl"] || "0"),
      volume_24h: parse_float(data["volume24h"] || data["volume"] || "0"),
      apy: parse_float(data["apy"] || "0"),
      base_apy: parse_float(data["baseApy"] || "0"),
      reward_apy: parse_float(data["rewardApy"] || "0"),
      pool_type: data["poolType"] || data["type"] || "stableswap",
      chain: data["chain"] || "ethereum"
    }
  end

  defp parse_pool_stats(data) do
    %{
      address: data["address"] || "",
      tvl: parse_float(data["tvl"] || "0"),
      volume_24h: parse_float(data["volume24h"] || "0"),
      volume_7d: parse_float(data["volume7d"] || "0"),
      fee: parse_float(data["fee"] || "0"),
      token_price: parse_float(data["tokenPrice"] || "0")
    }
  end

  defp parse_swap_quote(data) do
    %{
      pool_address: data["poolAddress"] || "",
      from_coin: data["fromCoin"] || "",
      to_coin: data["toCoin"] || "",
      input_amount: parse_float(data["inputAmount"] || "0"),
      output_amount: parse_float(data["outputAmount"] || "0"),
      price_impact: parse_float(data["priceImpact"] || "0"),
      fee: parse_float(data["fee"] || "0")
    }
  end

  defp parse_gauge(data) do
    %{
      address: data["address"] || data["gaugeAddress"] || "",
      pool_address: data["poolAddress"] || "",
      reward_token: data["rewardToken"] || "CRV",
      reward_rate: parse_float(data["rewardRate"] || "0"),
      total_supply: parse_float(data["totalSupply"] || "0"),
      apy: parse_float(data["apy"] || "0"),
      working_supply: parse_float(data["workingSupply"] || "0")
    }
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end