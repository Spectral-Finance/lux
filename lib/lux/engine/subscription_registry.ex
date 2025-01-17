defmodule Lux.Engine.SubscriptionRegistry do
  @moduledoc """
  Registry for managing signal subscriptions and pattern matching.
  """

  use GenServer
  require Logger
  alias Lux.Engine.Subscription.Pattern

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end

  def register(registry, specter_id, pattern) do
    GenServer.call(via_tuple(registry), {:register, specter_id, pattern})
  end

  def unregister(registry, specter_id) do
    GenServer.call(via_tuple(registry), {:unregister, specter_id})
  end

  def find_matching_specters(registry, signal) do
    GenServer.call(via_tuple(registry), {:find_matching_specters, signal})
  end

  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    {registry, _} = extract_registry_name(name)
    subscriptions = :ets.new(:"#{registry}_subscriptions", [:set, :protected])
    {:ok, %{name: name, subscriptions: subscriptions}}
  end

  def handle_call({:register, specter_id, pattern}, _from, state) do
    Logger.debug("Registering pattern: #{inspect(pattern)} for specter: #{inspect(specter_id)}")
    :ets.insert(state.subscriptions, {specter_id, pattern})
    {:reply, :ok, state}
  end

  def handle_call({:unregister, specter_id}, _from, state) do
    :ets.delete(state.subscriptions, specter_id)
    {:reply, :ok, state}
  end

  def handle_call({:find_matching_specters, signal}, _from, state) do
    Logger.debug("Finding matches for signal: #{inspect(signal)}")

    matches =
      :ets.foldl(
        fn {specter_id, pattern}, acc ->
          Logger.debug(
            "Checking pattern: #{inspect(pattern.pattern)} for specter: #{inspect(specter_id)}"
          )

          case Pattern.match?(pattern, signal) do
            {:ok, _priority} ->
              Logger.debug("Pattern matched!")
              [specter_id | acc]

            :nomatch ->
              Logger.debug("Pattern did not match")
              acc
          end
        end,
        [],
        state.subscriptions
      )

    {:reply, matches, state}
  end

  defp via_tuple(name) do
    {registry, process_name} = extract_registry_name(name)
    {:via, Registry, {registry, process_name}}
  end

  defp extract_registry_name({registry, name}), do: {registry, "subscription_registry_#{name}"}
  defp extract_registry_name(name) when is_atom(name), do: {name, "subscription_registry"}
end
