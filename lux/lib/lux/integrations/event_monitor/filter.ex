defmodule Lux.Integrations.EventMonitor.Filter do
  @moduledoc "Event filtering and alert matching."
  @spec matches?(map(), map()) :: boolean()
  def matches?(rule, event) do
    cond do
      rule.type == "topic_match" -> Enum.all?(rule.topics, fn t -> t == "*" or t in event.topics end)
      rule.type == "value_range" -> matches_range(rule.field, rule.min, rule.max, Map.get(event, rule.field))
      rule.type == "contract_address" -> event.contract == rule.address
      rule.type == "block_range" -> matches_block(rule.from, rule.to, event.block_number)
      true -> false
    end
  end
  defp matches_range(_f, min, max, v) when is_number(v), do: v >= min and v <= max
  defp matches_range(_f, _min, _max, _v), do: false
  defp matches_block(from, to, block) when is_number(block) do
    (is_nil(from) or block >= from) and (is_nil(to) or block <= to)
  end
  defp matches_block(_from, _to, _block), do: false
end