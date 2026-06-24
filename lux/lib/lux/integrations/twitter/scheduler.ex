defmodule Lux.Integrations.Twitter.Scheduler do
  @moduledoc """
  Scheduling system for executing queued tweets.
  """
  use GenServer
  require Logger

  alias Lux.Integrations.Twitter.Queue
  alias Lux.Integrations.Twitter.Client

  @poll_interval 60_000 # 1 minute

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    if Keyword.get(opts, :auto_start, true) do
      schedule_poll()
    end
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    due_items = Queue.dequeue_due()
    
    Enum.each(due_items, fn item ->
      try do
        Client.create_tweet(item.text)
        Logger.info("Successfully posted scheduled tweet: #{String.slice(item.text, 0, 20)}...")
      rescue
        e ->
          Logger.error("Failed to post tweet: #{inspect(e)}")
          # Re-enqueue on failure or handle error based on business rules
          Queue.enqueue(item.text, DateTime.add(DateTime.utc_now(), 300, :second))
      end
    end)

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
