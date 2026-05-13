defmodule Lux.Web3.EventMonitor.Matcher do
  @moduledoc """
  Matches normalized events against contract subscriptions.
  """

  alias Lux.Web3.EventMonitor.{Event, Subscription}

  @spec match?(Subscription.t(), Event.t()) :: boolean()
  def match?(%Subscription{} = subscription, %Event{} = event) do
    subscription.chain_id == event.chain_id and
      subscription.contract_address == event.contract_address and
      in_block_range?(subscription, event.block_number) and
      topics_match?(subscription.topics, event.topics)
  end

  @spec matching_subscriptions([Subscription.t()], Event.t()) :: [Subscription.t()]
  def matching_subscriptions(subscriptions, %Event{} = event) do
    Enum.filter(subscriptions, &match?(&1, event))
  end

  defp in_block_range?(%Subscription{from_block: from_block, to_block: :latest}, block_number),
    do: block_number >= from_block

  defp in_block_range?(%Subscription{from_block: from_block, to_block: to_block}, block_number),
    do: block_number >= from_block and block_number <= to_block

  defp topics_match?([], _topics), do: true

  defp topics_match?(filters, topics) when length(filters) > length(topics), do: false

  defp topics_match?(filters, topics) do
    filters
    |> Enum.zip(topics)
    |> Enum.all?(fn {filter, topic} -> topic_matches?(filter, topic) end)
  end

  defp topic_matches?(nil, _topic), do: true
  defp topic_matches?(expected, topic) when is_binary(expected), do: expected == topic
  defp topic_matches?(expected, topic) when is_list(expected), do: topic in expected
end
