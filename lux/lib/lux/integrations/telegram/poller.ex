defmodule Lux.Integrations.Telegram.Poller do
  @moduledoc """
  A GenServer that continuously polls the Telegram Bot API `getUpdates` endpoint.
  """
  use GenServer
  require Logger
  alias Lux.Integrations.Telegram.Client

  @default_timeout 30

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    handler = Keyword.get(opts, :handler) || raise ArgumentError, "Missing required option :handler for Telegram.Poller"
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    state = %{
      offset: 0,
      handler: handler,
      timeout: timeout,
      polling: true
    }

    send(self(), :poll)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    if state.polling do
      new_offset = perform_poll(state.offset, state.timeout, state.handler)
      send(self(), :poll)
      {:noreply, %{state | offset: new_offset}}
    else
      {:noreply, state}
    end
  end

  def handle_call(:stop, _from, state) do
    {:reply, :ok, %{state | polling: false}}
  end

  defp perform_poll(offset, timeout, handler) do
    opts = %{
      json: %{
        offset: offset,
        timeout: timeout,
        allowed_updates: []
      }
    }

    case Client.request(:post, "/getUpdates", opts) do
      {:ok, %{"ok" => true, "result" => updates}} when is_list(updates) ->
        Enum.each(updates, fn update ->
          # Dispatch update to handler
          # The handler should implement handle_update/1
          try do
            if function_exported?(handler, :handle_update, 1) do
              handler.handle_update(update)
            else
              Logger.warning("Telegram Handler module #{inspect(handler)} does not export handle_update/1")
            end
          rescue
            e ->
              Logger.error("Error in Telegram update handler: #{Exception.message(e)}")
          end
        end)

        calculate_next_offset(offset, updates)

      {:error, reason} ->
        Logger.error("Telegram Poller encountered error: #{inspect(reason)}")
        # Backoff a bit on error to avoid spamming the API
        Process.sleep(2000)
        offset
    end
  end

  defp calculate_next_offset(current_offset, []) do
    current_offset
  end

  defp calculate_next_offset(_current_offset, updates) do
    last_update = List.last(updates)
    last_update["update_id"] + 1
  end
end
