defmodule Lux.Integrations.SmartContractEvents.Filter do
  @moduledoc "Event filtering and pattern matching"

  @doc "Create a filter specification"
  def create(opts) do
    %{
      address: opts[:address],
      topics: opts[:topics] || [],
      from_block: opts[:from_block],
      to_block: opts[:to_block],
      pattern: opts[:pattern] || :any
    }
  end

  @doc "Match an event against a filter"
  def match?(event, filter) do
    address_match?(event.address, filter.address) and
    topics_match?(event.topics, filter.topics) and
    pattern_match?(event, filter.pattern)
  end

  defp address_match?(_event_addr, nil), do: true
  defp address_match?(event_addr, filter_addr), do: String.downcase(event_addr) == String.downcase(filter_addr)

  defp topics_match?(_event_topics, []), do: true
  defp topics_match?(event_topics, filter_topics) do
    Enum.with_index(filter_topics)
    |> Enum.all?(fn {topic, idx} ->
      topic == nil or (idx < length(event_topics) and Enum.at(event_topics, idx) == topic)
    end)
  end

  defp pattern_match?(_event, :any), do: true
  defp pattern_match?(event, pattern) when is_function(pattern, 1), do: pattern.(event)
  defp pattern_match?(_event, _), do: true
end
