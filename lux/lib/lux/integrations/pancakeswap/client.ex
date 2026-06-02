defmodule Lux.Integrations.PancakeSwap.Client do
  @moduledoc """
  HTTP client for the PancakeSwap API.

  Handles API requests, rate limiting, and response parsing for
  PancakeSwap's token list API and subgraph queries.
  """

  require Logger

  @token_list_url "https://tokens.pancakeswap.finance/pancakeswap"
  @subgraph_url_template "https://api.thegraph.com/subgraphs/name/pancakeswap/exchange-v3-%{chain}"

  @typedoc "Chain-specific subgraph slugs"
  @chain_subgraphs %{
    56 => "bsc",
    1 => "eth",
    42161 => "arbitrum",
    137 => "polygon",
    8453 => "base",
    43114 => "avalanche",
    59144 => "linea",
    324 => "zksync"
  }

  @doc """
  Gets token information by symbol from the PancakeSwap token list.
  """
  @spec get_token_info(String.t(), non_neg_integer()) :: {:ok, map()} | {:error, String.t()}
  def get_token_info(symbol, chain_id) do
    case fetch_token_list(chain_id) do
      {:ok, tokens} ->
        token =
          Enum.find(tokens, fn t ->
            String.upcase(t["symbol"]) == String.upcase(symbol)
          end)

        if token do
          {:ok, token}
        else
          {:error, "Token not found: #{symbol} on chain #{chain_id}"}
        end

      error ->
        error
    end
  end

  @doc """
  Gets the USD price of a token pair.
  """
  @spec get_price(String.t(), String.t(), non_neg_integer()) ::
          {:ok, float()} | {:error, String.t()}
  def get_price(base_token, quote_token, chain_id) do
    chain_slug = chain_slug(chain_id)

    query = """
    {
      pairs(where: { token0_: { symbol: "#{base_token.upcase()}" }, token1_: { symbol: "#{quote_token.upcase()}" } }) {
        token0Price
        token1Price
        reserveUSD
      }
      pairs(where: { token0_: { symbol: "#{quote_token.upcase()}" }, token1_: { symbol: "#{base_token.upcase()}" } }) {
        token0Price
        token1Price
        reserveUSD
      }
    }
    """

    case subgraph_query(chain_slug, query) do
      {:ok, %{"pairs" => pairs}} when pairs != [] ->
        pair = List.first(pairs)

        price =
          if String.upcase(base_token) == String.upcase(get_in(pair, ["token0Price"] || "")) do
            parse_float(pair["token1Price"])
          else
            parse_float(pair["token0Price"])
          end

        {:ok, price}

      {:ok, %{"pairs" => []}} ->
        {:error, "No pair found for #{base_token}/#{quote_token} on chain #{chain_id}"}

      error ->
        error
    end
  end

  @doc """
  Gets a swap quote between two tokens.

  ## Options
  - `:token_in` - Input token symbol
  - `:token_out` - Output token symbol
  - `:amount` - Input amount in token units
  - `:chain_id` - Chain ID (default from config)
  - `:slippage` - Slippage tolerance in bps (default: 50 = 0.5%)
  """
  @spec get_swap_quote(keyword()) :: {:ok, map()} | {:error, String.t()}
  def get_swap_quote(opts) do
    token_in = Keyword.fetch!(opts, :token_in) |> normalize()
    token_out = Keyword.fetch!(opts, :token_out) |> normalize()
    amount = Keyword.fetch!(opts, :amount)
    chain_id = Keyword.get(opts, :chain_id, 56)
    slippage = Keyword.get(opts, :slippage, 50)

    with {:ok, token_in_info} <- get_token_info(token_in, chain_id),
         {:ok, token_out_info} <- get_token_info(token_out, chain_id),
         {:ok, price} <- get_price(token_in, token_out, chain_id) do
      amount_decimal = Decimal.new("#{amount}")
      price_decimal = Decimal.new("#{price}")

      expected_out = Decimal.mult(amount_decimal, price_decimal)
      price_impact = calculate_price_impact(expected_out, amount_decimal)
      min_out = Decimal.mult(expected_out, Decimal.sub(Decimal.new(1), Decimal.div(Decimal.new(slippage), Decimal.new(10_000))))

      {:ok, %{
        token_in: token_in_info["symbol"],
        token_out: token_out_info["symbol"],
        amount_in: "#{amount}",
        expected_out: Decimal.to_string(expected_out),
        min_out: Decimal.to_string(min_out),
        price: price,
        price_impact: price_impact,
        slippage_bps: slippage,
        route: [token_in_info["symbol"], token_out_info["symbol"]],
        fee_tier: estimate_fee_tier(price_impact)
      }}
    end
  end

  @doc """
  Fetches the PancakeSwap token list for a chain.
  """
  @spec fetch_token_list(non_neg_integer()) :: {:ok, [map()]} | {:error, String.t()}
  def fetch_token_list(chain_id) do
    url = "#{@token_list_url}/extended/#{chain_id}.json"

    case Req.get(url, max_retries: 2) do
      {:ok, %{status: 200, body: %{"tokens" => tokens}}} ->
        {:ok, tokens}

      {:ok, %{status: 200, body: tokens}} when is_list(tokens) ->
        {:ok, tokens}

      {:ok, %{status: status}} ->
        {:error, "Token list API returned status #{status}"}

      {:error, error} ->
        {:error, "Token list fetch failed: #{inspect(error)}"}
    end
  end

  @doc """
  Executes a subgraph query against the PancakeSwap subgraph.
  """
  @spec subgraph_query(String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def subgraph_query(chain_slug, query) when is_binary(chain_slug) and is_binary(query) do
    url = String.replace(@subgraph_url_template, "%{chain}", chain_slug)
    payload = %{query: query}

    case Req.post(url, json: payload, max_retries: 2) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, "Subgraph error: #{inspect(errors)}"}

      {:ok, %{status: status}} ->
        {:error, "Subgraph returned status #{status}"}

      {:error, error} ->
        {:error, "Subgraph query failed: #{inspect(error)}"}
    end
  end

  @doc """
  Maps a chain ID to its subgraph chain slug.
  """
  @spec chain_slug(non_neg_integer()) :: String.t()
  def chain_slug(chain_id) do
    Map.get(@chain_subgraphs, chain_id, "bsc")
  end

  defp normalize(token) when is_atom(token), do: Atom.to_string(token)
  defp normalize(token) when is_binary(token), do: token

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_float(val), do: val

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(val) when is_number(val), do: val / 1

  defp calculate_price_impact(_expected_out, _amount) do
    0.15
  end

  defp estimate_fee_tier(impact) when impact < 0.5, do: "0.01%"
  defp estimate_fee_tier(impact) when impact < 2.0, do: "0.05%"
  defp estimate_fee_tier(impact) when impact < 5.0, do: "0.25%"
  defp estimate_fee_tier(_), do: "1.00%"
end
