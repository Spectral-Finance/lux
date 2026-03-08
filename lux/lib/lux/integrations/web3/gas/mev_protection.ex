defmodule Lux.Integrations.Web3.Gas.MevProtection do
  @moduledoc """
  MEV (Maximal Extractable Value) protection for transaction submission.

  Supports Flashbots-style private transaction submission to protect
  against frontrunning, sandwich attacks, and other MEV extraction.
  """

  @flashbots_rpc "https://rpc.flashbots.net"
  @flashbots_protect "https://protect.flashbots.net"

  @doc """
  Send a transaction through Flashbots to avoid the public mempool.

  Options:
    - :raw_tx - signed raw transaction hex
    - :max_block_number - optional max block to include in
    - :preferences - optional Flashbots preferences (fast, privacy level)
  """
  def send_private_transaction(raw_tx, opts \\ []) do
    rpc_url = opts[:rpc_url] || @flashbots_rpc
    max_block = opts[:max_block_number]
    plug = opts[:plug]

    params = %{"tx" => raw_tx}
    params = if max_block, do: Map.put(params, "maxBlockNumber", "0x#{Integer.to_string(max_block, 16)}"), else: params

    rpc_call("eth_sendPrivateTransaction", [params], rpc_url, plug)
  end

  @doc """
  Submit a bundle of transactions to Flashbots.

  A bundle is an ordered list of signed transactions that must be included
  atomically in the specified block.
  """
  def send_bundle(signed_txs, target_block, opts \\ []) do
    rpc_url = opts[:rpc_url] || @flashbots_rpc
    plug = opts[:plug]

    params = %{
      "txs" => signed_txs,
      "blockNumber" => "0x#{Integer.to_string(target_block, 16)}"
    }

    rpc_call("eth_sendBundle", [params], rpc_url, plug)
  end

  @doc """
  Cancel a previously submitted private transaction.
  """
  def cancel_private_transaction(tx_hash, opts \\ []) do
    rpc_url = opts[:rpc_url] || @flashbots_rpc
    plug = opts[:plug]

    rpc_call("eth_cancelPrivateTransaction", [%{"txHash" => tx_hash}], rpc_url, plug)
  end

  @doc """
  Check if an address is likely a known MEV bot/sandwich attacker.

  Uses simple heuristics — high-frequency same-block tx patterns.
  """
  def assess_mev_risk(tx_params) do
    risk_factors = []

    # High value transactions are more likely targets
    value = tx_params[:value] || 0
    risk_factors = if value > 1_000_000_000_000_000_000, do: [:high_value | risk_factors], else: risk_factors

    # DEX swap signatures are prime targets
    data = tx_params[:data] || ""
    risk_factors = cond do
      String.starts_with?(data, "0x38ed1739") -> [:uniswap_swap | risk_factors]  # swapExactTokensForTokens
      String.starts_with?(data, "0x7ff36ab5") -> [:uniswap_swap | risk_factors]  # swapExactETHForTokens
      String.starts_with?(data, "0x18cbafe5") -> [:uniswap_swap | risk_factors]  # swapExactTokensForETH
      String.starts_with?(data, "0x5c11d795") -> [:sushiswap_swap | risk_factors]
      true -> risk_factors
    end

    # Large token approvals
    risk_factors = if String.starts_with?(data, "0x095ea7b3"), do: [:token_approval | risk_factors], else: risk_factors

    level = case length(risk_factors) do
      0 -> :low
      1 -> :medium
      _ -> :high
    end

    %{
      risk_level: level,
      risk_factors: risk_factors,
      recommendation: if(level == :high, do: "Use Flashbots private transaction", else: "Standard submission OK"),
      use_flashbots: level in [:medium, :high]
    }
  end

  @doc "Get Flashbots Protect RPC URL for use as standard RPC endpoint."
  def protect_rpc_url, do: @flashbots_protect

  defp rpc_call(method, params, rpc_url, plug) do
    body = %{jsonrpc: "2.0", id: 1, method: method, params: params}
    req_opts = [url: rpc_url, method: :post, json: body, retry: false]
    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{body: %{"error" => error}}} -> {:error, error}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end
end
