defmodule Lux.Integrations.SmartContractEvents.Monitor do
  @moduledoc "Real-time event monitoring GenServer"

  use GenServer
  alias Lux.Integrations.SmartContractEvents.{Parser, Filter, Webhook, Store}

  @check_interval 5_000

  def start_link(subscription) do
    GenServer.start_link(__MODULE__, subscription, name: :"event_monitor_#{subscription.id}")
  end

  @impl true
  def init(subscription) do
    schedule_check()
    {:ok, %{subscription: subscription, last_block: subscription.from_block}}
  end

  @impl true
  def handle_info(:check_events, state) do
    new_state = check_for_new_events(state)
    schedule_check()
    {:noreply, new_state}
  end

  defp check_for_new_events(state) do
    sub = state.subscription
    config = sub.chain_config

    current_block = get_current_block(config.rpc)
    from = state.last_block || sub.from_block

    if current_block > from do
      payload = %{
        jsonrpc: "2.0", id: 1, method: "eth_getLogs",
        params: [%{
          fromBlock: encode_block(from),
          toBlock: encode_block(current_block),
          address: sub.contract,
          topics: [sub.event_signature]
        }]
      }

      case rpc_call(config.rpc, payload) do
        {:ok, logs} ->
          events = Enum.map(logs, fn log -> Parser.decode_log(log, sub.filter) end)
          |> Enum.filter(fn e -> e != nil and Filter.matches_filter?(e, sub.filter) end)

          Enum.each(events, fn event ->
            Store.store_event(event)
            Webhook.notify(sub.webhook, event)
          end)

          %{state | last_block: current_block}
        _ -> state
      end
    else
      state
    end
  end

  defp get_current_block(rpc_url) do
    payload = %{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []}
    case rpc_call(rpc_url, payload) do
      {:ok, %{"result" => hex}} -> String.to_integer(String.trim_leading(hex, "0x"), 16)
      _ -> 0
    end
  end

  defp encode_block("latest"), do: "latest"
  defp encode_block(n) when is_integer(n), do: "0x" <> Integer.to_string(n, 16)

  defp rpc_call(url, payload) do
    case HTTPoison.post(url, Jason.encode!(payload), [{"Content-Type", "application/json"}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode!(body) do
          %{"result" => result} -> {:ok, %{"result" => result}}
          %{"error" => error} -> {:error, error}
        end
      error -> {:error, error}
    end
  end

  defp schedule_check do
    Process.send_after(self(), :check_events, @check_interval)
  end
end
