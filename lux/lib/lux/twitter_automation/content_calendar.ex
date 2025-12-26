defmodule Lux.TwitterAutomation.ContentCalendar do
  @moduledoc """
  Content calendar management for planned social media posts.

  Features:
  - Create and organize content items
  - Tag-based categorization
  - Status tracking (draft, scheduled, published, failed)
  - Integration with Scheduler for auto-publishing
  """

  use GenServer
  require Logger

  alias Lux.TwitterAutomation.{Storage, Scheduler}

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Add content to calendar"
  def add_content(content, publish_date, opts \\ %{}) do
    GenServer.call(__MODULE__, {:add_content, content, publish_date, opts})
  end

  @doc "Update content"
  def update_content(id, changes) do
    GenServer.call(__MODULE__, {:update_content, id, changes})
  end

  @doc "Delete content"
  def delete_content(id) do
    GenServer.call(__MODULE__, {:delete_content, id})
  end

  @doc "Schedule content for publishing"
  def schedule_content(id) do
    GenServer.call(__MODULE__, {:schedule_content, id})
  end

  @doc "Get calendar view (date range)"
  def get_calendar(start_date, end_date) do
    GenServer.call(__MODULE__, {:get_calendar, start_date, end_date})
  end

  @doc "Get content by tag"
  def get_content_by_tag(tag) do
    GenServer.call(__MODULE__, {:get_content_by_tag, tag})
  end

  @doc "Get content by status"
  def get_content_by_status(status) do
    GenServer.call(__MODULE__, {:get_content_by_status, status})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{auto_publish: true}}
  end

  @impl true
  def handle_call({:add_content, content, publish_date, opts}, _from, state) do
    item = %{
      id: generate_id(),
      content: content,
      publish_date: publish_date,
      status: :draft,
      tags: opts[:tags] || [],
      category: opts[:category],
      metadata: opts[:metadata] || %{},
      created_at: DateTime.utc_now()
    }

    Storage.store_calendar_item(item)
    Logger.info("Added content #{item.id} to calendar")

    {:reply, {:ok, item.id}, state}
  end

  @impl true
  def handle_call({:update_content, id, changes}, _from, state) do
    case Storage.get_calendar_item(id) do
      {:ok, item} ->
        updated_item = Map.merge(item, Map.new(changes))
        Storage.store_calendar_item(updated_item)
        Logger.info("Updated content #{id}")
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:delete_content, id}, _from, state) do
    Storage.delete_calendar_item(id)
    Logger.info("Deleted content #{id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:schedule_content, id}, _from, state) do
    case Storage.get_calendar_item(id) do
      {:ok, item} ->
        # Schedule with Scheduler
        tweet_content = extract_tweet_content(item.content)

        case Scheduler.schedule_tweet(tweet_content, item.publish_date, %{
               metadata: %{calendar_item_id: id}
             }) do
          {:ok, schedule_id} ->
            # Update status to scheduled
            updated_item = %{item | status: :scheduled, metadata: Map.put(item.metadata, :schedule_id, schedule_id)}
            Storage.store_calendar_item(updated_item)
            Logger.info("Scheduled content #{id} for publishing")
            {:reply, {:ok, schedule_id}, state}

          error ->
            {:reply, error, state}
        end

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:get_calendar, start_date, end_date}, _from, state) do
    result = Storage.get_calendar_range(start_date, end_date)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_content_by_tag, tag}, _from, state) do
    result = Storage.get_content_by_tag(tag)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_content_by_status, status}, _from, state) do
    result = Storage.get_content_by_status(status)
    {:reply, result, state}
  end

  ## Private Functions

  defp extract_tweet_content(content) when is_binary(content), do: content

  defp extract_tweet_content(content) when is_map(content) do
    # Handle structured content (text + media)
    content[:text] || content["text"] || ""
  end

  defp extract_tweet_content(_), do: ""

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
