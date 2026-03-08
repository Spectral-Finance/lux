defmodule Lux.Lenses.Web3.Events.GetContractEvents do
  @moduledoc """
  Lens for fetching and decoding smart contract events from any EVM chain.
  """

  alias Lux.Integrations.Web3.Events.EventDecoder

  def focus(params, _opts \\ []) do
    rpc_url = params[:rpc_url] || params["rpc_url"]
    address = params[:address] || params["address"]
    from_block = params[:from_block] || params["from_block"] || "latest"
    to_block = params[:to_block] || params["to_block"] || "latest"
    event_type = params[:event_type] || params["event_type"]

    filter = %{
      "fromBlock" => normalize_block(from_block),
      "toBlock" => normalize_block(to_block)
    }
    filter = if address, do: Map.put(filter, "address", address), else: filter
    filter = if event_type do
      topic = event_type_to_topic(event_type)
      if topic, do: Map.put(filter, "topics", [topic]), else: filter
    else
      filter
    end

    req_opts = [
      url: rpc_url,
      method: :post,
      json: %{jsonrpc: "2.0", id: 1, method: "eth_getLogs", params: [filter]},
      retry: false
    ]
    req_opts = if params[:plug], do: Keyword.put(req_opts, :plug, params[:plug]), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: 200, body: %{"result" => logs}}} when is_list(logs) ->
        decoded = Enum.map(logs, &EventDecoder.decode/1)

        decoded = if event_type do
          type_atom = String.to_existing_atom(event_type)
          Enum.filter(decoded, &(&1.type == type_atom))
        else
          decoded
        end

        {:ok, %{events: decoded, count: length(decoded)}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @event_topics %{
    "transfer" => "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
    "approval" => "0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925",
    "swap" => "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822",
    "deposit" => "0xe1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c",
    "withdrawal" => "0x7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65"
  }

  defp event_type_to_topic(type), do: Map.get(@event_topics, type)

  defp normalize_block("latest"), do: "latest"
  defp normalize_block(n) when is_integer(n), do: "0x#{Integer.to_string(n, 16)}"
  defp normalize_block(s), do: s
end
