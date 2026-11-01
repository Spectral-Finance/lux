defmodule Lux.Web3.EventMonitor.FilterEngine do
  @moduledoc """
  Pattern matching and rule-filtering engine for smart contract events (#75).

  Evaluates complex criteria including:
  - Exact or wildcard topic matching
  - Value thresholds (e.g. transfer amounts, liquidity limits)
  - Address whitelists and blacklists
  - Custom parameter predicates
  """

  alias Lux.Web3.EventMonitor.Schemas.{MonitoredEvent, Subscription, FilterPattern}

  @doc """
  Determines if an event satisfies the subscription's topic and filter pattern criteria.
  """
  @spec matches?(MonitoredEvent.t(), Subscription.t()) :: boolean()
  def matches?(%MonitoredEvent{} = event, %Subscription{} = sub) do
    chain_matches?(event, sub) and
      contract_matches?(event, sub) and
      topic0_matches?(event, sub) and
      pattern_matches?(event, sub.filter_pattern)
  end

  defp chain_matches?(event, sub) do
    is_nil(sub.chain_id) or event.chain_id == sub.chain_id or event.chain == sub.chain
  end

  defp contract_matches?(event, sub) do
    case sub.contract_address do
      nil -> true
      "*" -> true
      list when is_list(list) ->
        clean_list = Enum.map(list, &String.downcase(to_string(&1)))
        event.contract_address in clean_list
      addr when is_binary(addr) ->
        String.downcase(addr) == event.contract_address
      _ -> false
    end
  end

  defp topic0_matches?(event, sub) do
    cond do
      is_nil(sub.topic0) or sub.topic0 == "*" ->
        true

      true ->
        case event.topics do
          [t0 | _] -> String.downcase(t0) == String.downcase(sub.topic0)
          _ -> false
        end
    end
  end

  @doc """
  Evaluates a FilterPattern against the decoded parameters of a MonitoredEvent.
  """
  @spec pattern_matches?(MonitoredEvent.t(), map() | FilterPattern.t()) :: boolean()
  def pattern_matches?(_event, nil), do: true
  def pattern_matches?(_event, pattern) when pattern == %{}, do: true

  def pattern_matches?(%MonitoredEvent{decoded_params: params}, %FilterPattern{} = pattern) do
    eval_pattern_rules(params, Map.from_struct(pattern))
  end

  def pattern_matches?(%MonitoredEvent{decoded_params: params}, pattern) when is_map(pattern) do
    eval_pattern_rules(params, pattern)
  end

  defp eval_pattern_rules(params, pattern) do
    min_ok = check_min_value(params, pattern[:min_value] || pattern["min_value"])
    max_ok = check_max_value(params, pattern[:max_value] || pattern["max_value"])
    from_ok = check_address_whitelist(params, [:from, :sender, :owner, "from", "sender", "owner"], pattern[:from_whitelist] || pattern["from_whitelist"])
    to_ok = check_address_whitelist(params, [:to, :recipient, :spender, "to", "recipient", "spender"], pattern[:to_whitelist] || pattern["to_whitelist"])
    blacklist_ok = check_address_blacklist(params, pattern[:address_blacklist] || pattern["address_blacklist"])
    predicates_ok = check_custom_predicates(params, pattern[:parameter_conditions] || pattern["parameter_conditions"])

    min_ok and max_ok and from_ok and to_ok and blacklist_ok and predicates_ok
  end

  defp check_min_value(_params, nil), do: true
  defp check_min_value(params, min_val) when is_number(min_val) do
    extracted = extract_numeric_value(params)
    extracted >= min_val
  end
  defp check_min_value(_params, _), do: true

  defp check_max_value(_params, nil), do: true
  defp check_max_value(params, max_val) when is_number(max_val) do
    extracted = extract_numeric_value(params)
    extracted <= max_val
  end
  defp check_max_value(_params, _), do: true

  defp extract_numeric_value(params) do
    # Search common value keys: :value, :amount, :amount0In, :amount1In, :wad
    cond do
      is_number(params[:value]) -> params[:value]
      is_number(params["value"]) -> params["value"]
      is_number(params[:amount]) -> params[:amount]
      is_number(params["amount"]) -> params["amount"]
      is_number(params[:wad]) -> params[:wad]
      is_number(params["wad"]) -> params["wad"]
      true -> 0
    end
  end

  defp check_address_whitelist(_params, _keys, nil), do: true
  defp check_address_whitelist(_params, _keys, []), do: true
  defp check_address_whitelist(params, keys, whitelist) when is_list(whitelist) do
    clean_whitelist = Enum.map(whitelist, &String.downcase(to_string(&1)))

    matched_addr =
      Enum.find_value(keys, fn k ->
        case Map.get(params, k) do
          nil -> nil
          addr when is_binary(addr) -> String.downcase(addr)
          _ -> nil
        end
      end)

    case matched_addr do
      nil -> true # Field not present in this event, pass through
      addr -> addr in clean_whitelist
    end
  end

  defp check_address_blacklist(_params, nil), do: true
  defp check_address_blacklist(_params, []), do: true
  defp check_address_blacklist(params, blacklist) when is_list(blacklist) do
    clean_blacklist = Enum.map(blacklist, &String.downcase(to_string(&1)))

    # Collect all address values in params
    addresses =
      params
      |> Map.values()
      |> Enum.filter(&is_binary/1)
      |> Enum.filter(&String.starts_with?(&1, "0x"))
      |> Enum.map(&String.downcase/1)

    # Disallow if any address in params is in the blacklist
    Enum.all?(addresses, fn addr -> addr not in clean_blacklist end)
  end

  defp check_custom_predicates(_params, nil), do: true
  defp check_custom_predicates(_params, map) when map == %{}, do: true
  defp check_custom_predicates(params, conditions) when is_map(conditions) do
    Enum.all?(conditions, fn {k, expected} ->
      actual = Map.get(params, k) || Map.get(params, to_string(k))

      case expected do
        {:gte, val} -> is_number(actual) and actual >= val
        {:lte, val} -> is_number(actual) and actual <= val
        {:eq, val} -> actual == val
        {:in, list} when is_list(list) -> actual in list
        val -> actual == val
      end
    end)
  end
end
