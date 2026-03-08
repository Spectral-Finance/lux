defmodule Lux.Lenses.Web3.Chain.GetTransaction do
  @moduledoc """
  Lens for fetching transaction data and receipts from any EVM chain.
  """

  alias Lux.Integrations.Web3.Chain.RpcClient

  def focus(params, _opts \\ []) do
    tx_hash = params[:tx_hash] || params["tx_hash"]
    action = params[:action] || params["action"] || "transaction"

    case action do
      "transaction" -> get_transaction(tx_hash, params)
      "receipt" -> get_receipt(tx_hash, params)
      "both" -> get_both(tx_hash, params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp get_transaction(tx_hash, params) do
    case RpcClient.call("eth_getTransactionByHash", [tx_hash], build_opts(params)) do
      {:ok, nil} -> {:error, "Transaction not found"}
      {:ok, tx} -> {:ok, parse_transaction(tx)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_receipt(tx_hash, params) do
    case RpcClient.call("eth_getTransactionReceipt", [tx_hash], build_opts(params)) do
      {:ok, nil} -> {:ok, %{status: :pending}}
      {:ok, receipt} -> {:ok, parse_receipt(receipt)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_both(tx_hash, params) do
    with {:ok, tx} <- get_transaction(tx_hash, params),
         {:ok, receipt} <- get_receipt(tx_hash, params) do
      {:ok, Map.merge(tx, %{receipt: receipt})}
    end
  end

  defp parse_transaction(tx) do
    %{
      hash: tx["hash"],
      from: tx["from"],
      to: tx["to"],
      value: parse_hex(tx["value"]),
      gas: parse_hex(tx["gas"]),
      gas_price: parse_hex(tx["gasPrice"]),
      nonce: parse_hex(tx["nonce"]),
      block_number: parse_hex(tx["blockNumber"]),
      input: tx["input"],
      type: parse_hex(tx["type"])
    }
  end

  defp parse_receipt(r) do
    %{
      status: if(r["status"] == "0x1", do: :confirmed, else: :failed),
      block_number: parse_hex(r["blockNumber"]),
      gas_used: parse_hex(r["gasUsed"]),
      effective_gas_price: parse_hex(r["effectiveGasPrice"]),
      logs: Enum.map(r["logs"] || [], &parse_log/1),
      contract_address: r["contractAddress"]
    }
  end

  defp parse_log(log) do
    %{
      address: log["address"],
      topics: log["topics"],
      data: log["data"],
      log_index: parse_hex(log["logIndex"]),
      block_number: parse_hex(log["blockNumber"])
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
