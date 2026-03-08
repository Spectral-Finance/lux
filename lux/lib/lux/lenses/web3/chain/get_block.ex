defmodule Lux.Lenses.Web3.Chain.GetBlock do
  @moduledoc """
  Lens for fetching block data from any supported EVM chain.
  """

  alias Lux.Integrations.Web3.Chain.RpcClient

  def focus(params, _opts \\ []) do
    rpc_url = params[:rpc_url] || params["rpc_url"]
    block = params[:block] || params["block"] || "latest"
    full_tx = params[:full_transactions] || params["full_transactions"] || false

    block_param = normalize_block(block)

    case RpcClient.call("eth_getBlockByNumber", [block_param, full_tx], build_opts(params)) do
      {:ok, nil} -> {:error, "Block not found"}
      {:ok, block_data} -> {:ok, parse_block(block_data)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_block("latest"), do: "latest"
  defp normalize_block("pending"), do: "pending"
  defp normalize_block("earliest"), do: "earliest"
  defp normalize_block(n) when is_integer(n), do: "0x#{Integer.to_string(n, 16)}"
  defp normalize_block("0x" <> _ = hex), do: hex
  defp normalize_block(s) when is_binary(s), do: "0x#{Integer.to_string(String.to_integer(s), 16)}"

  defp parse_block(b) do
    %{
      number: parse_hex(b["number"]),
      hash: b["hash"],
      parent_hash: b["parentHash"],
      timestamp: parse_hex(b["timestamp"]),
      gas_used: parse_hex(b["gasUsed"]),
      gas_limit: parse_hex(b["gasLimit"]),
      base_fee_per_gas: parse_hex(b["baseFeePerGas"]),
      transaction_count: length(b["transactions"] || []),
      transactions: b["transactions"],
      miner: b["miner"]
    }
  end

  defp parse_hex(nil), do: nil
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(v), do: v

  defp build_opts(params) do
    opts = [rpc_url: params[:rpc_url] || params["rpc_url"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
