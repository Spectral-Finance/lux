defmodule Lux.Integrations.Web3.Gas.Estimator do
  @moduledoc """
  Gas price estimation and prediction using multiple strategies.

  Fetches gas prices, estimates transaction costs, and predicts optimal
  timing for gas-efficient transactions.
  """

  @doc "Estimate gas prices with slow/standard/fast tiers."
  def estimate(opts \\ []) do
    rpc_url = opts[:rpc_url] || raise "RPC URL required"

    req_opts = [url: rpc_url, method: :post, retry: false]
    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    with {:ok, gas_price} <- rpc_call("eth_gasPrice", [], req_opts),
         {:ok, base_fee} <- get_base_fee(req_opts),
         {:ok, max_priority} <- rpc_call("eth_maxPriorityFeePerGas", [], req_opts) do
      gas_price_gwei = to_gwei(parse_hex(gas_price))
      base_fee_gwei = to_gwei(base_fee)
      priority_gwei = to_gwei(parse_hex(max_priority))

      {:ok, %{
        slow: %{
          max_fee_per_gas: round_gwei(base_fee_gwei * 1.0 + priority_gwei * 0.8),
          max_priority_fee: round_gwei(priority_gwei * 0.8),
          estimated_time: "~5 min"
        },
        standard: %{
          max_fee_per_gas: round_gwei(base_fee_gwei * 1.2 + priority_gwei),
          max_priority_fee: round_gwei(priority_gwei),
          estimated_time: "~1 min"
        },
        fast: %{
          max_fee_per_gas: round_gwei(base_fee_gwei * 1.5 + priority_gwei * 1.5),
          max_priority_fee: round_gwei(priority_gwei * 1.5),
          estimated_time: "~15 sec"
        },
        base_fee_gwei: round_gwei(base_fee_gwei),
        gas_price_gwei: round_gwei(gas_price_gwei)
      }}
    else
      {:error, _} = err -> err
    end
  end

  @doc "Estimate gas for a specific transaction."
  def estimate_gas(tx_params, opts \\ []) do
    rpc_url = opts[:rpc_url] || raise "RPC URL required"

    req_opts = [url: rpc_url, method: :post, retry: false]
    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    call_params = %{}
    call_params = if tx_params[:from], do: Map.put(call_params, "from", tx_params[:from]), else: call_params
    call_params = Map.put(call_params, "to", tx_params[:to])
    call_params = if tx_params[:value], do: Map.put(call_params, "value", "0x#{Integer.to_string(tx_params[:value], 16)}"), else: call_params
    call_params = if tx_params[:data], do: Map.put(call_params, "data", tx_params[:data]), else: call_params

    case rpc_call("eth_estimateGas", [call_params], req_opts) do
      {:ok, hex} ->
        gas = parse_hex(hex)
        # Add 20% buffer
        {:ok, %{gas_estimate: gas, gas_with_buffer: round(gas * 1.2)}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Calculate transaction cost in ETH and USD."
  def calculate_cost(gas_limit, gas_price_gwei, eth_price_usd \\ nil) do
    cost_wei = gas_limit * round(gas_price_gwei * 1.0e9)
    cost_eth = cost_wei / 1.0e18

    result = %{gas_limit: gas_limit, gas_price_gwei: gas_price_gwei, cost_eth: Float.round(cost_eth, 8)}

    if eth_price_usd do
      Map.put(result, :cost_usd, Float.round(cost_eth * eth_price_usd, 4))
    else
      result
    end
  end

  defp get_base_fee(req_opts) do
    case rpc_call("eth_getBlockByNumber", ["latest", false], req_opts) do
      {:ok, %{"baseFeePerGas" => fee}} -> {:ok, parse_hex(fee)}
      {:ok, _} -> {:ok, 0}
      error -> error
    end
  end

  defp rpc_call(method, params, req_opts) do
    body = %{jsonrpc: "2.0", id: 1, method: method, params: params}
    case Req.request(Keyword.put(req_opts, :json, body)) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(n) when is_integer(n), do: n
  defp parse_hex(_), do: 0

  defp to_gwei(wei), do: wei / 1.0e9

  defp round_gwei(gwei), do: Float.round(gwei * 1.0, 2)
end
