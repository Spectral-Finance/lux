defmodule Lux.Integrations.Telegram.Polling do
  @moduledoc """
  A GenServer that polls Telegram for updates and dispatches them to a handler.
  """

  use GenServer
  require Logger

  alias Lux.Lenses.Telegram.GetUpdates

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    state = %{
      handler: Keyword.fetch!(opts, :handler),
      offset: Keyword.get(opts, :offset, 0),
      limit: Keyword.get(opts, :limit, 100),
      timeout: Keyword.get(opts, :timeout, 30),
      allowed_updates: Keyword.get(opts, :allowed_updates, [])
    }

    send(self(), :poll)
    {:ok, state}
  end

  def handle_info(:poll, state) do
    params = %{
      "offset" => state.offset,
      "limit" => state.limit,
      "timeout" => state.timeout
    }
    
    params = if state.allowed_updates != [], do: Map.put(params, "allowed_updates", state.allowed_updates), else: params

    case GetUpdates.focus(params) do
      {:ok, updates} ->
        new_offset = Enum.reduce(updates, state.offset, fn update, acc ->
          dispatch_update(update, state.handler)
          max(acc, update["update_id"] + 1)
        end)

        schedule_poll()
        {:noreply, %{state | offset: new_offset}}

      {:error, reason} ->
        Logger.error("Telegram polling error: #{inspect(reason)}")
        schedule_poll(5000)
        {:noreply, state}
    end
  end

  defp dispatch_update(update, handler) when is_function(handler, 1) do
    handler.(update)
  end

  defp dispatch_update(update, {module, function}) do
    apply(module, function, [update])
  end

  defp schedule_poll(delay \\ 0) do
    Process.send_after(self(), :poll, delay)
  end
end
