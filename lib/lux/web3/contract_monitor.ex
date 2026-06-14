
defmodule Lux.Web3.ContractMonitor do
  @moduledoc "Smart contract event monitoring system for real-time blockchain activity tracking."
  def monitor_event(contract, event_name, callback \\ nil, chain \\ :ethereum) do
    rpc = rpc_url(chain)
    sig = event_signature(event_name)
    filter = %{address: contract, topics: [sig]}
    case json_rpc(rpc, "eth_newFilter", [filter]) do
      {:ok, filter_id} -> {:ok, %{filter_id: filter_id, contract: contract, event: event_name, callback: callback}}
      error -> error
    end
  end
  def get_logs(contract, event_name, from_block, to_block \\ "latest", chain \\ :ethereum) do
    rpc = rpc_url(chain)
    sig = event_signature(event_name)
    filter = %{address: contract, topics: [sig], fromBlock: from_block, toBlock: to_block}
    case json_rpc(rpc, "eth_getLogs", [filter]) do
      {:ok, logs} -> {:ok, %{logs: logs, count: length(logs), contract: contract, event: event_name}}
      error -> error
    end
  end
  def get_filter_changes(filter_id, chain \\ :ethereum) do
    case json_rpc(rpc_url(chain), "eth_getFilterChanges", [filter_id]) do
      {:ok, changes} -> {:ok, %{filter_id: filter_id, changes: changes, count: length(changes)}}
      error -> error
    end
  end
  defp event_signature(name), do: ExKeccak.hash_256(name) |> Base.encode16(case: :downcase) |> String.slice(0, 10)
  defp rpc_url(:ethereum), do: Application.get_env(:lux, :ethereum_rpc) || "https://eth.llamarpc.com"
  defp rpc_url(chain), do: Application.get_env(:lux, :"#{chain}_rpc") || "https://#{chain}.llamarpc.com"
  defp json_rpc(url, method, params) do
    case Req.post(url, json: %{jsonrpc: "2.0", id: 1, method: method, params: params}, headers: [{"Content-Type", "application/json"}]) do
      {:ok, %{status: 200, body: %{"result" => r}}} -> {:ok, r}
      {:ok, %{status: 200, body: %{"error" => e}}} -> {:error, e}
      {:error, err} -> {:error, inspect(err)}
    end
  end
end
