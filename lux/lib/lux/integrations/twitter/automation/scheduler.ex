defmodule Lux.Integrations.Twitter.Automation.Scheduler do
  @moduledoc """
  Manages scheduled tweets, thread publishing queues, and priority-based execution ordering.
  Supports retry policies, failure handling, and status tracking.
  """

  @type item_id :: String.t()
  @type priority :: :high | :normal | :low
  @type status :: :pending | :published | :failed | :cancelled

  @type scheduled_item :: %{
          id: item_id(),
          text: String.t(),
          media_ids: list(String.t()),
          thread_items: list(String.t()),
          scheduled_at: DateTime.t(),
          priority: priority(),
          status: status(),
          attempts: non_neg_integer(),
          max_attempts: pos_integer(),
          published_tweet_id: String.t() | nil,
          error_reason: String.t() | nil,
          metadata: map()
        }

  @type queue :: %{item_id() => scheduled_item()}

  @priority_weight %{high: 1, normal: 2, low: 3}

  @doc """
  Initializes an empty scheduler queue map.
  """
  @spec new_queue() :: queue()
  def new_queue, do: %{}

  @doc """
  Schedules a new tweet or thread for publishing.
  """
  @spec schedule(queue(), map()) :: {:ok, queue(), scheduled_item()} | {:error, term()}
  def schedule(queue, params) when is_map(queue) and is_map(params) do
    text = Map.get(params, :text) || Map.get(params, "text")

    if is_nil(text) or text == "" do
      {:error, :empty_text}
    else
      scheduled_at = parse_datetime(Map.get(params, :scheduled_at) || Map.get(params, "scheduled_at"))
      priority = parse_priority(Map.get(params, :priority) || Map.get(params, "priority", :normal))
      media_ids = Map.get(params, :media_ids) || Map.get(params, "media_ids", [])
      thread_items = Map.get(params, :thread_items) || Map.get(params, "thread_items", [])
      max_attempts = Map.get(params, :max_attempts) || Map.get(params, "max_attempts", 3)
      metadata = Map.get(params, :metadata) || Map.get(params, "metadata", %{})

      id = "sched_#{System.system_time(:second)}_#{:rand.uniform(999_999)}"

      item = %{
        id: id,
        text: text,
        media_ids: media_ids,
        thread_items: thread_items,
        scheduled_at: scheduled_at,
        priority: priority,
        status: :pending,
        attempts: 0,
        max_attempts: max_attempts,
        published_tweet_id: nil,
        error_reason: nil,
        metadata: metadata
      }

      {:ok, Map.put(queue, id, item), item}
    end
  end

  def schedule(_queue, _params), do: {:error, :invalid_params}

  @doc """
  Cancels a pending scheduled item.
  """
  @spec cancel(queue(), item_id()) :: {:ok, queue(), scheduled_item()} | {:error, :not_found}
  def cancel(queue, item_id) do
    case Map.get(queue, item_id) do
      nil ->
        {:error, :not_found}

      item ->
        updated = %{item | status: :cancelled}
        {:ok, Map.put(queue, item_id, updated), updated}
    end
  end

  @doc """
  Reschedules an existing item to a new timestamp.
  """
  @spec reschedule(queue(), item_id(), DateTime.t() | String.t()) ::
          {:ok, queue(), scheduled_item()} | {:error, term()}
  def reschedule(queue, item_id, new_time) do
    case Map.get(queue, item_id) do
      nil ->
        {:error, :not_found}

      item ->
        new_dt = parse_datetime(new_time)
        updated = %{item | scheduled_at: new_dt, status: :pending, error_reason: nil}
        {:ok, Map.put(queue, item_id, updated), updated}
    end
  end

  @doc """
  Returns a list of items due for publication up to `as_of` (defaults to DateTime.utc_now()).
  Sorted by priority then scheduled_at.
  """
  @spec get_due_items(queue(), DateTime.t()) :: list(scheduled_item())
  def get_due_items(queue, as_of \\ DateTime.utc_now()) do
    queue
    |> Map.values()
    |> Enum.filter(fn item ->
      item.status == :pending and DateTime.compare(item.scheduled_at, as_of) in [:lt, :eq]
    end)
    |> Enum.sort_by(fn item ->
      {@priority_weight[item.priority] || 2, DateTime.to_unix(item.scheduled_at)}
    end)
  end

  @doc """
  Marks an item as successfully published with the returned tweet_id.
  """
  @spec mark_published(queue(), item_id(), String.t()) :: {:ok, queue(), scheduled_item()} | {:error, :not_found}
  def mark_published(queue, item_id, tweet_id) do
    case Map.get(queue, item_id) do
      nil ->
        {:error, :not_found}

      item ->
        updated = %{
          item
          | status: :published,
            published_tweet_id: tweet_id,
            attempts: item.attempts + 1
        }

        {:ok, Map.put(queue, item_id, updated), updated}
    end
  end

  @doc """
  Records a failed attempt for an item. If attempts exceed max_attempts, status becomes :failed.
  """
  @spec mark_failed(queue(), item_id(), String.t()) :: {:ok, queue(), scheduled_item()} | {:error, :not_found}
  def mark_failed(queue, item_id, reason) do
    case Map.get(queue, item_id) do
      nil ->
        {:error, :not_found}

      item ->
        new_attempts = item.attempts + 1
        new_status = if new_attempts >= item.max_attempts, do: :failed, else: :pending

        updated = %{
          item
          | status: new_status,
            attempts: new_attempts,
            error_reason: reason
        }

        {:ok, Map.put(queue, item_id, updated), updated}
    end
  end

  @doc """
  Filters items in the queue by status or priority.
  """
  @spec list_items(queue(), map()) :: list(scheduled_item())
  def list_items(queue, filters \\ %{}) do
    status_filter = Map.get(filters, :status)
    priority_filter = Map.get(filters, :priority)

    queue
    |> Map.values()
    |> Enum.filter(fn item ->
      (is_nil(status_filter) or item.status == status_filter) and
        (is_nil(priority_filter) or item.priority == priority_filter)
    end)
    |> Enum.sort_by(&DateTime.to_unix(&1.scheduled_at))
  end

  # --- Internal Helpers ---

  defp parse_datetime(%DateTime{} = dt), do: dt

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_datetime(unix_ts) when is_integer(unix_ts) do
    DateTime.from_unix!(unix_ts)
  end

  defp parse_datetime(_), do: DateTime.utc_now()

  defp parse_priority(:high), do: :high
  defp parse_priority(:low), do: :low
  defp parse_priority("high"), do: :high
  defp parse_priority("low"), do: :low
  defp parse_priority(_), do: :normal
end
