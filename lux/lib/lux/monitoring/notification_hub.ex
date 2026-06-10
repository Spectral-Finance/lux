defmodule Lux.Monitoring.NotificationHub do
  @moduledoc """
  Handles dispatching of monitored events to external webhooks.
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    # Map of event_signature -> [webhook_urls]
    {:ok, %{subscriptions: %{}}}
  end

  def subscribe(event_signature, url) do
    GenServer.cast(__MODULE__, {:subscribe, event_signature, url})
  end

  @impl true
  def handle_cast({:subscribe, sig, url}, state) do
    new_subs = Map.update(state.subscriptions, sig, [url], &[url | &1])
    {:noreply, %{state | subscriptions: new_subs}}
  end

  def notify(event_data) do
    GenServer.cast(__MODULE__, {:notify, event_data})
  end

  @impl true
  def handle_cast({:notify, event_data}, state) do
    sig = event_data.signature
    urls = Map.get(state.subscriptions, sig, [])
    
    Enum.each(urls, fn url ->
      # In production, use an HTTP client like HTTPoison or Mint
      Logger.info("[NotificationHub] Sending event to #{url}: #{inspect(event_data)}")
    end)
    
    {:noreply, state}
  end
end
