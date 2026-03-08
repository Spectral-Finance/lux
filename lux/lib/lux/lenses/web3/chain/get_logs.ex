defmodule Lux.Lenses.Web3.Chain.GetLogs do
  @moduledoc """
  Lens for fetching and filtering smart contract event logs across chains.
  """

  alias Lux.Integrations.Web3.Chain.RpcClient

  def focus(params, _opts \\ []) do
    filter = build_filter(params)

    case RpcClient.call("eth_getLogs", [filter], build_opts(params)) do
      {:ok, logs} ->
        parsed = Enum.map(logs, &parse_log/1)
        {:ok, %{logs: parsed, count: length(parsed)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_filter(params) do
    filter = %{}
    filter = maybe_put(filter, "fromBlock", normalize_block(params[:from_block] || params["from_block"]))
    filter = maybe_put(filter, "toBlock", normalize_block(params[:to_block] || params["to_block"]))
    filter = maybe_put(filter, "address", params[:address] || params["address"])
    filter = maybe_put(filter, "topics", params[:topics] || params["topics"])
    filter
  end

  defp normalize_block(nil), do: nil
  defp normalize_block("latest"), do: "latest"
  defp normalize_block(n) when is_integer(n), do: "0x#{Integer.to_string(n, 16)}"
  defp normalize_block(s), do: s

  defp parse_log(log) do
    %{
      address: log["address"],
      topics: log["topics"],
      data: log["data"],
      block_number: parse_hex(log["blockNumber"]),
      transaction_hash: log["transactionHash"],
      log_index: parse_hex(log["logIndex"]),
      block_hash: log["blockHash"],
      removed: log["removed"] || false
    }
  end

  defp parse_hex(nil), do: nil
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(v), do: v

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp build_opts(params) do
    opts = [rpc_url: params[:rpc_url] || params["rpc_url"]]
    if params[:plug], do: Keyword.put(opts, :plug, params[:plug]), else: opts
  end
end
