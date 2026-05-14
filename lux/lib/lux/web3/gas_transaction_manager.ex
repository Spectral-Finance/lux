defmodule Lux.Web3.GasTransactionManager do
  @moduledoc """
  Deterministic gas optimization and transaction management helpers.

  This module builds execution plans only. It does not hold keys, sign payloads,
  or broadcast transactions, which keeps fee planning and safety checks testable
  before another transport layer sends a transaction.
  """

  @gwei 1_000_000_000
  @default_gas_limit 21_000
  @replacement_bump_percent 12

  @doc "Predicts EIP-1559 fee tiers from current observations and optional history."
  def predict_gas(attrs) when is_map(attrs) do
    observations = value(attrs, :observations, attrs)

    with {:ok, base_fee} <-
           read_wei(observations, [:base_fee_per_gas, :base_fee, :suggest_base_fee]),
         {:ok, priority_fee} <-
           read_wei(observations, [:priority_fee_per_gas, :priority_fee, :propose_gas_price]) do
      history = value(attrs, :history, [])

      ratio =
        congestion_ratio(value(observations, :gas_used_ratio, value(attrs, :gas_used_ratio, 0.5)))

      history_base =
        median_history(history, [:base_fee_per_gas, :base_fee, :suggest_base_fee], base_fee)

      history_priority =
        median_history(
          history,
          [:priority_fee_per_gas, :priority_fee, :propose_gas_price],
          priority_fee
        )

      predicted_base = max(base_fee, history_base) |> bump_by_congestion(ratio)
      predicted_priority = max(priority_fee, history_priority)
      tiers = fee_tiers(predicted_base, predicted_priority)
      selected_tier = attrs |> value(:urgency, :standard) |> normalize_atom()
      selected = Map.get(tiers, selected_tier, tiers.standard)

      {:ok,
       %{
         network: value(attrs, :network, "ethereum"),
         base_fee_per_gas: predicted_base,
         priority_fee_per_gas: predicted_priority,
         congestion: congestion(ratio),
         selected_tier: selected_tier,
         selected: selected,
         tiers: tiers,
         generated_at: value(attrs, :now)
       }}
    end
  end

  @doc "Builds a stable transaction batching plan with gas and fee caps."
  def batch_transactions(transactions, opts \\ %{}) when is_list(transactions) do
    with {:ok, default_fee} <- optional_wei(value(opts, :max_fee_per_gas, 0)) do
      planned =
        transactions
        |> Enum.with_index()
        |> Enum.map(fn {tx, index} -> normalize_transaction(tx, index, default_fee) end)
        |> Enum.sort_by(fn tx ->
          {tx.chain_id, tx.from || "", tx.nonce || 0, -tx.priority, tx.index}
        end)

      batches =
        planned
        |> Enum.group_by(&batch_key/1)
        |> Enum.map(fn {_key, group} -> build_batch(group, opts) end)
        |> Enum.sort_by(& &1.first_order)
        |> Enum.with_index(1)
        |> Enum.map(fn {batch, id} -> Map.put(batch, :batch_id, id) end)

      {:ok,
       %{
         batch_count: length(batches),
         transaction_count: length(planned),
         batches: batches,
         total_gas_limit: Enum.sum(Enum.map(batches, & &1.gas_limit)),
         max_fee_cap_wei: Enum.sum(Enum.map(batches, & &1.max_fee_cap_wei)),
         execution_notes: [
           "Transactions are ordered by chain, sender, nonce, priority, then insertion order.",
           "Multicall mode is selected only when a batch_contract is present for every transaction in the group."
         ]
       }}
    end
  end

  @doc "Builds a same-nonce speed-up or cancel replacement transaction."
  def replacement_transaction(attrs) when is_map(attrs) do
    original = value(attrs, :transaction, attrs)
    action = attrs |> value(:action, :speed_up) |> normalize_atom()
    bump_percent = value(attrs, :bump_percent, @replacement_bump_percent)

    with :ok <- ensure_known(action, [:speed_up, :cancel], :unknown_replacement_action),
         {:ok, max_fee} <- read_wei(original, [:max_fee_per_gas, :gas_price]),
         {:ok, priority_fee} <-
           read_wei(original, [:max_priority_fee_per_gas, :priority_fee_per_gas, :gas_price]),
         {:ok, nonce} <- required(original, :nonce),
         {:ok, from} <- required(original, :from) do
      bumped_max_fee = bump_percent(max_fee, bump_percent)
      bumped_priority_fee = bump_percent(priority_fee, bump_percent)

      replacement =
        original
        |> Map.put(:nonce, nonce)
        |> Map.put(:from, from)
        |> Map.put(:max_fee_per_gas, bumped_max_fee)
        |> Map.put(:max_priority_fee_per_gas, bumped_priority_fee)
        |> apply_replacement_action(action, from)

      {:ok,
       %{
         action: action,
         replacement: replacement,
         replacement_policy: %{
           same_nonce: true,
           bump_percent: bump_percent,
           original_max_fee_per_gas: max_fee,
           new_max_fee_per_gas: bumped_max_fee,
           original_max_priority_fee_per_gas: priority_fee,
           new_max_priority_fee_per_gas: bumped_priority_fee
         }
       }}
    end
  end

  @doc "Builds a private relay and bundle policy for MEV-sensitive transactions."
  def mev_protection_plan(attrs) when is_map(attrs) do
    risk = attrs |> value(:risk, :medium) |> normalize_atom()
    relays = value(attrs, :relays, ["flashbots", "mev-share"])
    private? = risk in [:high, :critical] or value(attrs, :private_required, false)

    {:ok,
     %{
       risk: risk,
       route: if(private?, do: :private_relay, else: :public_with_guards),
       relays: if(private?, do: relays, else: []),
       simulation_required: true,
       public_mempool_allowed: not private?,
       deadline_seconds: value(attrs, :deadline_seconds, 120),
       slippage_bps: value(attrs, :slippage_bps, 50),
       replacement_policy: %{
         enabled: true,
         min_bump_percent: value(attrs, :min_bump_percent, @replacement_bump_percent)
       },
       fallback: if(private?, do: :cancel_or_retry_private, else: :speed_up_or_cancel),
       warnings: mev_warnings(attrs, private?)
     }}
  end

  @doc "Plans native gas reserve, gas-token, and paymaster requirements."
  def gas_token_strategy(attrs) when is_map(attrs) do
    with {:ok, native_balance} <- read_wei(attrs, [:native_balance_wei, :native_balance]),
         {:ok, planned_fee} <- read_wei(attrs, [:planned_max_fee_wei, :planned_fee_wei]) do
      buffer_percent = value(attrs, :buffer_percent, 20)
      required = bump_percent(planned_fee, buffer_percent)
      top_up = max(required - native_balance, 0)
      paymaster = value(attrs, :paymaster)

      {:ok,
       %{
         native_token: value(attrs, :native_token, "ETH"),
         status: if(top_up == 0, do: :funded, else: :top_up_required),
         native_balance_wei: native_balance,
         required_native_reserve_wei: required,
         top_up_wei: top_up,
         paymaster: paymaster,
         gas_token_mode: if(paymaster, do: :account_abstraction_paymaster, else: :native_token),
         warnings: [
           "Legacy refund gas tokens are not recommended after EIP-3529; keep native fee reserve or use a reviewed paymaster."
         ]
       }}
    end
  end

  @doc "Runs deterministic transaction preflight checks and returns an executable call request."
  def simulate_transaction(attrs) when is_map(attrs) do
    tx = value(attrs, :transaction, attrs)

    with {:ok, max_fee} <- read_wei(tx, [:max_fee_per_gas, :gas_price]),
         {:ok, value_wei} <- optional_wei(value(tx, :value_wei, value(tx, :value, 0))),
         {:ok, balance} <-
           optional_wei(value(attrs, :account_balance_wei, value(attrs, :account_balance, 0))) do
      gas_limit = gas_limit(tx)
      max_fee_cost = gas_limit * max_fee
      required_balance = max_fee_cost + value_wei
      nonce_issue = nonce_issue(tx, attrs)

      errors =
        []
        |> maybe_add(required_balance > balance, :insufficient_balance)
        |> maybe_add(nonce_issue != nil, nonce_issue)
        |> maybe_add(not valid_data?(value(tx, :data, "0x")), :invalid_calldata)

      {:ok,
       %{
         status: if(errors == [], do: :ok, else: :blocked),
         errors: Enum.reverse(errors),
         gas_limit: gas_limit,
         max_fee_cost_wei: max_fee_cost,
         value_wei: value_wei,
         required_balance_wei: required_balance,
         account_balance_wei: balance,
         call_request: %{
           from: value(tx, :from),
           to: value(tx, :to),
           value: value_wei,
           data: value(tx, :data, "0x"),
           gas: gas_limit,
           max_fee_per_gas: max_fee,
           max_priority_fee_per_gas: value(tx, :max_priority_fee_per_gas)
         }
       }}
    end
  end

  @doc "Builds a cost analysis report for a set of transactions."
  def cost_report(attrs) when is_map(attrs) do
    transactions = value(attrs, :transactions, [])
    fee_plan = value(attrs, :fee_plan, %{})
    selected = value(fee_plan, :selected, fee_plan)

    with {:ok, expected_fee} <-
           read_wei(selected, [:expected_fee_per_gas, :max_fee_per_gas, :gas_price]),
         {:ok, max_fee} <-
           read_wei(selected, [:max_fee_per_gas, :expected_fee_per_gas, :gas_price]),
         {:ok, baseline_fee} <- optional_wei(value(attrs, :baseline_fee_per_gas, max_fee)) do
      rows =
        transactions
        |> Enum.map(fn tx ->
          gas = gas_limit(tx)
          value_wei = tx |> value(:value_wei, value(tx, :value, 0)) |> parse_wei!()

          %{
            id: value(tx, :id, value(tx, :nonce)),
            gas_limit: gas,
            expected_fee_wei: gas * expected_fee,
            max_fee_wei: gas * max_fee,
            value_wei: value_wei,
            total_max_cost_wei: gas * max_fee + value_wei,
            baseline_fee_wei: gas * baseline_fee,
            savings_wei: max(gas * baseline_fee - gas * expected_fee, 0)
          }
        end)

      {:ok,
       %{
         transaction_count: length(rows),
         rows: rows,
         totals: %{
           expected_fee_wei: sum(rows, :expected_fee_wei),
           max_fee_wei: sum(rows, :max_fee_wei),
           value_wei: sum(rows, :value_wei),
           total_max_cost_wei: sum(rows, :total_max_cost_wei),
           savings_wei: sum(rows, :savings_wei)
         },
         selected_tier: value(fee_plan, :selected_tier)
       }}
    end
  end

  @doc "Builds a full gas and transaction management plan."
  def management_plan(attrs) when is_map(attrs) do
    with {:ok, gas} <- predict_gas(attrs),
         {:ok, batches} <- batch_transactions(value(attrs, :transactions, []), gas.selected),
         {:ok, mev} <- mev_protection_plan(value(attrs, :mev, %{})),
         {:ok, report} <-
           cost_report(%{
             transactions: value(attrs, :transactions, []),
             fee_plan: gas,
             baseline_fee_per_gas:
               value(attrs, :baseline_fee_per_gas, gas.selected.max_fee_per_gas)
           }),
         {:ok, gas_token} <-
           gas_token_strategy(
             Map.merge(
               %{
                 native_balance_wei: value(attrs, :account_balance_wei, 0),
                 planned_max_fee_wei: report.totals.max_fee_wei
               },
               value(attrs, :gas_token, %{})
             )
           ) do
      simulations =
        attrs
        |> value(:transactions, [])
        |> Enum.map(fn tx ->
          tx
          |> Map.merge(%{
            max_fee_per_gas: gas.selected.max_fee_per_gas,
            max_priority_fee_per_gas: gas.selected.max_priority_fee_per_gas
          })
          |> then(
            &simulate_transaction(%{
              transaction: &1,
              account_balance_wei: value(attrs, :account_balance_wei, 0)
            })
          )
          |> elem(1)
        end)

      {:ok,
       %{
         gas: gas,
         batching: batches,
         mev_protection: mev,
         gas_token_strategy: gas_token,
         simulations: simulations,
         cost_report: report,
         ready: Enum.all?(simulations, &(&1.status == :ok))
       }}
    end
  end

  defp fee_tiers(base_fee, priority_fee) do
    %{
      slow: fee_tier(base_fee, priority_fee, 80, 115, 180),
      standard: fee_tier(base_fee, priority_fee, 100, 150, 90),
      fast: fee_tier(base_fee, priority_fee, 125, 200, 45),
      urgent: fee_tier(base_fee, priority_fee, 160, 250, 20)
    }
  end

  defp fee_tier(base_fee, priority_fee, priority_percent, base_percent, seconds) do
    max_priority = percent(priority_fee, priority_percent)
    max_fee = percent(base_fee, base_percent) + max_priority

    %{
      max_fee_per_gas: max_fee,
      max_priority_fee_per_gas: max_priority,
      expected_fee_per_gas: base_fee + max_priority,
      estimated_confirmation_seconds: seconds
    }
  end

  defp normalize_transaction(tx, index, default_fee) do
    gas = gas_limit(tx)
    fee = tx |> value(:max_fee_per_gas, value(tx, :gas_price, default_fee)) |> parse_wei!()

    %{
      index: index,
      order: index + 1,
      id: value(tx, :id, "tx-#{index + 1}"),
      chain_id: value(tx, :chain_id, 1),
      from: value(tx, :from),
      to: value(tx, :to),
      nonce: value(tx, :nonce, index),
      priority: value(tx, :priority, 0),
      batch_contract: value(tx, :batch_contract),
      allow_batch: value(tx, :allow_batch, true),
      gas_limit: gas,
      max_fee_per_gas: fee,
      max_fee_cap_wei: gas * fee,
      transaction: tx
    }
  end

  defp batch_key(tx), do: {tx.chain_id, tx.from, tx.batch_contract}

  defp build_batch(group, _opts) do
    multicall? = Enum.all?(group, &(&1.allow_batch and &1.batch_contract))
    gas_limit = Enum.sum(Enum.map(group, & &1.gas_limit))

    batched_gas =
      if multicall?, do: max(gas_limit - 10_000 * max(length(group) - 1, 0), 0), else: gas_limit

    %{
      first_order: group |> Enum.map(& &1.order) |> Enum.min(),
      execution_mode: if(multicall?, do: :multicall, else: :sequential),
      chain_id: hd(group).chain_id,
      from: hd(group).from,
      batch_contract: hd(group).batch_contract,
      transactions: Enum.map(group, &Map.drop(&1, [:transaction])),
      gas_limit: batched_gas,
      unbatched_gas_limit: gas_limit,
      gas_saved: gas_limit - batched_gas,
      max_fee_cap_wei: Enum.sum(Enum.map(group, & &1.max_fee_cap_wei))
    }
  end

  defp apply_replacement_action(tx, :speed_up, _from), do: tx

  defp apply_replacement_action(tx, :cancel, from) do
    tx
    |> Map.put(:to, from)
    |> Map.put(:value, 0)
    |> Map.put(:value_wei, 0)
    |> Map.put(:data, "0x")
    |> Map.put(:gas_limit, @default_gas_limit)
  end

  defp mev_warnings(attrs, private?) do
    []
    |> maybe_add(private? and value(attrs, :relays, []) == [], :missing_private_relays)
    |> maybe_add(value(attrs, :slippage_bps, 0) > 100, :wide_slippage)
    |> Enum.reverse()
  end

  defp gas_limit(tx) do
    case value(tx, :gas_limit) do
      nil -> @default_gas_limit + calldata_gas(value(tx, :data, "0x"))
      gas when is_integer(gas) -> gas
      gas when is_binary(gas) -> String.to_integer(gas)
    end
  end

  defp calldata_gas("0x"), do: 0

  defp calldata_gas(data) when is_binary(data) do
    data
    |> String.trim_leading("0x")
    |> byte_size()
    |> div(2)
    |> Kernel.*(16)
  end

  defp calldata_gas(_data), do: 0

  defp nonce_issue(tx, attrs) do
    nonce = value(tx, :nonce)
    pending = value(attrs, :pending_nonce)

    cond do
      is_nil(nonce) or is_nil(pending) -> nil
      nonce < pending -> :nonce_too_low
      nonce > pending -> :nonce_gap
      true -> nil
    end
  end

  defp valid_data?(data), do: is_binary(data) and String.match?(data, ~r/^0x[0-9a-fA-F]*$/)

  defp read_wei(map, keys) do
    keys
    |> Enum.map(&value(map, &1))
    |> Enum.find(&(&1 != nil))
    |> case do
      nil -> {:error, {:missing_wei_value, keys}}
      found -> parse_wei(found)
    end
  end

  defp optional_wei(nil), do: {:ok, 0}
  defp optional_wei(value), do: parse_wei(value)

  defp parse_wei!(value) do
    case parse_wei(value) do
      {:ok, wei} -> wei
      {:error, reason} -> raise ArgumentError, "invalid wei value: #{inspect(reason)}"
    end
  end

  defp parse_wei(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_wei(value) when is_binary(value) do
    normalized = String.trim(value)

    cond do
      String.starts_with?(normalized, "0x") ->
        normalized
        |> String.trim_leading("0x")
        |> Integer.parse(16)
        |> case do
          {int, ""} -> {:ok, int}
          _other -> {:error, {:invalid_wei, value}}
        end

      String.match?(normalized, ~r/^\d+$/) ->
        {:ok, String.to_integer(normalized)}

      String.match?(normalized, ~r/^\d+(\.\d+)?\s*gwei$/i) ->
        {:ok, parse_gwei(normalized)}

      true ->
        {:error, {:invalid_wei, value}}
    end
  end

  defp parse_wei(value), do: {:error, {:invalid_wei, value}}

  defp parse_gwei(value) do
    value
    |> String.downcase()
    |> String.replace("gwei", "")
    |> String.trim()
    |> String.split(".", parts: 2)
    |> case do
      [whole] ->
        String.to_integer(whole) * @gwei

      [whole, fraction] ->
        fraction_wei =
          fraction
          |> String.pad_trailing(9, "0")
          |> String.slice(0, 9)
          |> String.to_integer()

        String.to_integer(whole) * @gwei + fraction_wei
    end
  end

  defp median_history(history, keys, fallback) do
    values =
      history
      |> Enum.map(fn item ->
        case read_wei(item, keys) do
          {:ok, wei} -> wei
          {:error, _reason} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    case values do
      [] -> fallback
      list -> Enum.at(list, div(length(list), 2))
    end
  end

  defp congestion_ratio(value) when is_number(value), do: value

  defp congestion_ratio(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn part ->
      case Float.parse(part) do
        {float, _rest} -> float
        :error -> 0.5
      end
    end)
    |> then(fn ratios -> Enum.sum(ratios) / max(length(ratios), 1) end)
  end

  defp congestion_ratio(_value), do: 0.5

  defp congestion(ratio) do
    level =
      cond do
        ratio >= 0.9 -> :critical
        ratio >= 0.75 -> :high
        ratio >= 0.6 -> :elevated
        true -> :normal
      end

    %{ratio: ratio, level: level}
  end

  defp bump_by_congestion(value, ratio) do
    cond do
      ratio >= 0.9 -> percent(value, 125)
      ratio >= 0.75 -> percent(value, 115)
      ratio >= 0.6 -> percent(value, 108)
      true -> value
    end
  end

  defp bump_percent(value, percent), do: div(value * (100 + percent) + 99, 100)
  defp percent(value, percent), do: div(value * percent + 99, 100)

  defp sum(rows, key), do: rows |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sum()

  defp required(map, key) do
    case value(map, key) do
      nil -> {:error, {:missing_required, key}}
      found -> {:ok, found}
    end
  end

  defp ensure_known(value, known, error), do: if(value in known, do: :ok, else: {:error, error})

  defp normalize_atom(value) when is_atom(value), do: value

  defp normalize_atom(value) when is_binary(value),
    do: value |> String.downcase() |> String.to_atom()

  defp normalize_atom(value), do: value

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default

  defp maybe_add(list, true, value), do: [value | list]
  defp maybe_add(list, false, _value), do: list
end
