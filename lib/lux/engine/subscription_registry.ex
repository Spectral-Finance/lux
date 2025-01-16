defmodule Lux.Engine.SubscriptionRegistry do
  @moduledoc """
  Registry for storing and querying signal subscriptions using ETS.
  """

  alias Lux.Engine.Subscription
  require Logger

  @type table_ref :: atom() | :ets.tid()

  @doc """
  Initializes a subscription registry ETS table with a custom name.
  Returns the table reference.
  """
  @spec init(atom()) :: table_ref()
  def init(table_name) when is_atom(table_name) do
    :ets.new(table_name, [
      :named_table,
      :set,
      :public,
      read_concurrency: true
    ])
  end

  @doc """
  Cleans up the subscription registry by deleting the ETS table.
  """
  @spec cleanup(table_ref()) :: true
  def cleanup(table_ref) do
    :ets.delete(table_ref)
  end

  @doc """
  Registers a subscription in the registry.
  """
  @spec register(table_ref(), Subscription.t()) :: :ok
  def register(table_ref, %Subscription{} = subscription) do
    {key, value} = Subscription.to_ets_record(subscription)
    :ets.insert(table_ref, {key, value})
    :ok
  end

  @doc """
  Finds all specter IDs that have subscriptions matching the given signal.
  """
  @spec find_matching_specters(table_ref(), map()) :: [String.t()]
  def find_matching_specters(table_ref, signal) when is_map(signal) do
    table_ref
    |> :ets.tab2list()
    |> Enum.flat_map(fn {{pattern, _sub_id}, {_match_spec, specter_id}} ->
      if matches_pattern?(signal, pattern) do
        [specter_id]
      else
        []
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Removes all subscriptions for a given specter.
  """
  @spec unregister_specter(table_ref(), String.t()) :: :ok
  def unregister_specter(table_ref, target_specter_id) when is_binary(target_specter_id) do
    table_ref
    |> :ets.tab2list()
    |> Enum.each(fn {{pattern, sub_id}, {_match_spec, specter_id}} ->
      if specter_id == target_specter_id do
        :ets.delete(table_ref, {pattern, sub_id})
      end
    end)
    :ok
  end

  # Private helpers

  defp matches_pattern?(signal, pattern) do
    Enum.all?(pattern, fn {key, expected_value} ->
      case Map.get(signal, key) do
        nil -> false
        actual_value -> actual_value == expected_value
      end
    end)
  end
end
