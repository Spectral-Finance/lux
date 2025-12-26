defmodule Lux.TwitterAutomation.Storage do
  @moduledoc """
  ETS-based storage for Twitter Automation system.

  Manages four ETS tables:
  - `:automation_schedule` - Scheduled tweets and actions
  - `:automation_rules` - Engagement rules
  - `:automation_queue` - Action queue with priorities
  - `:automation_calendar` - Content calendar items
  """

  @schedule_table :automation_schedule
  @rules_table :automation_rules
  @queue_table :automation_queue
  @calendar_table :automation_calendar

  @doc "Initialize all ETS tables"
  def init do
    :ets.new(@schedule_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@rules_table, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@queue_table, [:ordered_set, :public, :named_table, read_concurrency: true])
    :ets.new(@calendar_table, [:set, :public, :named_table, read_concurrency: true])
    :ok
  end

  ## Scheduled Items

  @doc "Store a scheduled item"
  def store_scheduled_item(item) do
    :ets.insert(@schedule_table, {item.id, item})
    :ok
  end

  @doc "Get scheduled item by ID"
  def get_scheduled_item(id) do
    case :ets.lookup(@schedule_table, id) do
      [{^id, item}] -> {:ok, item}
      [] -> {:error, :not_found}
    end
  end

  @doc "Get all scheduled items by status"
  def get_scheduled_by_status(status) do
    items =
      :ets.tab2list(@schedule_table)
      |> Enum.map(fn {_id, item} -> item end)
      |> Enum.filter(fn item -> item.status == status end)

    {:ok, items}
  end

  @doc "Get scheduled items in time range"
  def get_scheduled_in_range(start_time, end_time) do
    items =
      :ets.tab2list(@schedule_table)
      |> Enum.map(fn {_id, item} -> item end)
      |> Enum.filter(fn item ->
        DateTime.compare(item.scheduled_time, start_time) in [:gt, :eq] and
          DateTime.compare(item.scheduled_time, end_time) in [:lt, :eq]
      end)
      |> Enum.sort_by(& &1.scheduled_time, DateTime)

    {:ok, items}
  end

  @doc "Update item status"
  def update_item_status(id, new_status) do
    case get_scheduled_item(id) do
      {:ok, item} ->
        updated_item = %{item | status: new_status}
        store_scheduled_item(updated_item)

      error ->
        error
    end
  end

  @doc "Delete scheduled item"
  def delete_scheduled_item(id) do
    :ets.delete(@schedule_table, id)
    :ok
  end

  ## Rules

  @doc "Store a rule"
  def store_rule(rule) do
    :ets.insert(@rules_table, {rule.id, rule})
    :ok
  end

  @doc "Get rule by ID"
  def get_rule(id) do
    case :ets.lookup(@rules_table, id) do
      [{^id, rule}] -> {:ok, rule}
      [] -> {:error, :not_found}
    end
  end

  @doc "Get all rules"
  def get_all_rules do
    rules =
      :ets.tab2list(@rules_table)
      |> Enum.map(fn {_id, rule} -> rule end)

    {:ok, rules}
  end

  @doc "Get enabled rules"
  def get_enabled_rules do
    rules =
      :ets.tab2list(@rules_table)
      |> Enum.map(fn {_id, rule} -> rule end)
      |> Enum.filter(& &1.enabled)

    {:ok, rules}
  end

  @doc "Delete rule"
  def delete_rule(id) do
    :ets.delete(@rules_table, id)
    :ok
  end

  ## Queue

  @doc "Enqueue an action"
  def enqueue_action(action) do
    # Use {priority, timestamp, id} as key for ordered_set ordering
    priority_value = priority_to_number(action.priority)
    key = {priority_value, action.created_at, action.id}
    :ets.insert(@queue_table, {key, action})
    :ok
  end

  @doc "Dequeue highest priority action"
  def dequeue_action do
    case :ets.first(@queue_table) do
      :"$end_of_table" ->
        {:ok, nil}

      key ->
        [{^key, action}] = :ets.lookup(@queue_table, key)
        :ets.delete(@queue_table, key)
        {:ok, action}
    end
  end

  @doc "Get queue size"
  def get_queue_size do
    :ets.info(@queue_table, :size)
  end

  @doc "Get queue stats"
  def get_queue_stats do
    items = :ets.tab2list(@queue_table) |> Enum.map(fn {_key, action} -> action end)

    {:ok,
     %{
       total: length(items),
       by_priority: Enum.group_by(items, & &1.priority) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new(),
       by_type: Enum.group_by(items, & &1.action_type) |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new()
     }}
  end

  ## Calendar

  @doc "Store calendar content"
  def store_calendar_item(item) do
    :ets.insert(@calendar_table, {item.id, item})
    :ok
  end

  @doc "Get calendar item by ID"
  def get_calendar_item(id) do
    case :ets.lookup(@calendar_table, id) do
      [{^id, item}] -> {:ok, item}
      [] -> {:error, :not_found}
    end
  end

  @doc "Get content by status"
  def get_content_by_status(status) do
    items =
      :ets.tab2list(@calendar_table)
      |> Enum.map(fn {_id, item} -> item end)
      |> Enum.filter(fn item -> item.status == status end)

    {:ok, items}
  end

  @doc "Get content by tag"
  def get_content_by_tag(tag) do
    items =
      :ets.tab2list(@calendar_table)
      |> Enum.map(fn {_id, item} -> item end)
      |> Enum.filter(fn item -> tag in (item.tags || []) end)

    {:ok, items}
  end

  @doc "Get calendar in date range"
  def get_calendar_range(start_date, end_date) do
    items =
      :ets.tab2list(@calendar_table)
      |> Enum.map(fn {_id, item} -> item end)
      |> Enum.filter(fn item ->
        item.publish_date &&
          DateTime.compare(item.publish_date, start_date) in [:gt, :eq] and
          DateTime.compare(item.publish_date, end_date) in [:lt, :eq]
      end)
      |> Enum.sort_by(& &1.publish_date, DateTime)

    {:ok, items}
  end

  @doc "Delete calendar item"
  def delete_calendar_item(id) do
    :ets.delete(@calendar_table, id)
    :ok
  end

  ## Utilities

  @doc "Clear all tables (for testing)"
  def clear_all do
    :ets.delete_all_objects(@schedule_table)
    :ets.delete_all_objects(@rules_table)
    :ets.delete_all_objects(@queue_table)
    :ets.delete_all_objects(@calendar_table)
    :ok
  end

  @doc "Get storage statistics"
  def get_stats do
    %{
      scheduled_count: :ets.info(@schedule_table, :size),
      rules_count: :ets.info(@rules_table, :size),
      queue_size: :ets.info(@queue_table, :size),
      calendar_count: :ets.info(@calendar_table, :size)
    }
  end

  # Helper: Convert priority atom to number for ordering
  defp priority_to_number(:high), do: 0
  defp priority_to_number(:normal), do: 1
  defp priority_to_number(:low), do: 2
  defp priority_to_number(_), do: 1
end
