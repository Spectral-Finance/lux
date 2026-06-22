defmodule Lux.Integrations.Web3.EventMonitor.Storage do
  @moduledoc """
  In-memory storage for smart contract events.
  Provides persistence for the event monitoring system.
  """
  use Agent

  @doc "Starts the event storage."
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc "Stores a new event."
  def insert(event) do
    Agent.update(__MODULE__, fn state -> [event | state] end)
  end

  @doc "Retrieves all events, optionally filtering by address or topic."
  def query(opts \\ []) do
    Agent.get(__MODULE__, fn state ->
      state
      |> filter_by_address(opts[:address])
      |> filter_by_topic(opts[:topic])
    end)
  end

  @doc "Clears all stored events."
  def clear do
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  defp filter_by_address(events, nil), do: events
  defp filter_by_address(events, address) do
    Enum.filter(events, fn ev -> 
      String.downcase(ev["address"] || "") == String.downcase(address)
    end)
  end

  defp filter_by_topic(events, nil), do: events
  defp filter_by_topic(events, topic) do
    Enum.filter(events, fn ev ->
      topics = ev["topics"] || []
      topic in topics
    end)
  end
end
