defmodule Lux.Web3.GasOptimizer do
  @moduledoc """
  Gas optimization helpers for EVM transactions.

  This module keeps fee planning deterministic and side-effect free so agents can
  estimate, batch, replace, or cancel transactions before handing them to a
  signing/broadcasting layer.
  """

  @gwei 1_000_000_000
  @default_bump_bps 1_250

  @type urgency :: :slow | :normal | :fast
  @type fee_plan :: %{
          base_fee_per_gas: non_neg_integer(),
          max_priority_fee_per_gas: non_neg_integer(),
          max_fee_per_gas: non_neg_integer(),
          urgency: urgency(),
          strategy: atom()
        }

  @doc """
  Builds an EIP-1559 fee recommendation from recent fee observations.

  Accepts integer wei values, decimal strings, or hex RPC quantities.
  """
  @spec recommend_eip1559_fee(map(), keyword() | map()) :: {:ok, fee_plan()} | {:error, term()}
  def recommend_eip1559_fee(fee_data, opts \\ %{}) do
    with {:ok, base_fee} <- fetch_wei(fee_data, :base_fee_per_gas),
         {:ok, samples} <- priority_samples(fee_data) do
      urgency = opts[:urgency] || :normal
      priority_fee = opts[:max_priority_fee_per_gas] || percentile(samples, urgency_percentile(urgency))
      multiplier_bps = opts[:base_fee_multiplier_bps] || urgency_base_multiplier_bps(urgency)

      {:ok,
       %{
         base_fee_per_gas: base_fee,
         max_priority_fee_per_gas: priority_fee,
         max_fee_per_gas: ceil_div(base_fee * multiplier_bps, 10_000) + priority_fee,
         urgency: urgency,
         strategy: :eip1559
       }}
    end
  end

  @doc """
  Creates a speed-up replacement transaction by bumping EIP-1559 or legacy fees.
  """
  @spec speed_up_transaction(map(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def speed_up_transaction(tx, opts \\ %{}) do
    bump_transaction(tx, opts)
  end

  @doc """
  Creates a cancel replacement transaction using the same nonce and bumped fees.
  """
  @spec cancel_transaction(map(), String.t(), keyword() | map()) :: {:ok, map()} | {:error, term()}
  def cancel_transaction(tx, from_address, opts \\ %{}) do
    with {:ok, replacement} <- bump_transaction(tx, opts) do
      {:ok,
       replacement
       |> Map.put(:to, from_address)
       |> Map.put(:value, 0)
       |> Map.put(:data, "0x")}
    end
  end

  @doc """
  Estimates worst-case gas cost for a transaction batch.
  """
  @spec analyze_batch([map()], map()) :: {:ok, map()} | {:error, term()}
  def analyze_batch(transactions, fee_plan) when is_list(transactions) do
    with {:ok, max_fee_per_gas} <- fetch_wei(fee_plan, :max_fee_per_gas),
         {:ok, rows} <- batch_rows(transactions, max_fee_per_gas) do
      total_gas = Enum.reduce(rows, 0, &(&1.gas_limit + &2))
      total_max_cost_wei = Enum.reduce(rows, 0, &(&1.max_cost_wei + &2))

      {:ok,
       %{
         count: length(rows),
         total_gas: total_gas,
         max_fee_per_gas: max_fee_per_gas,
         total_max_cost_wei: total_max_cost_wei,
         transactions: rows
       }}
    end
  end

  @doc """
  Sorts transactions into a stable execution order.

  Transactions with explicit nonces are ordered first by nonce. Transactions
  without nonces follow by descending priority and original insertion order.
  """
  @spec plan_batch([map()]) :: [map()]
  def plan_batch(transactions) do
    transactions
    |> Enum.with_index()
    |> Enum.sort_by(fn {tx, index} ->
      nonce = Map.get(tx, :nonce)
      priority = Map.get(tx, :priority, 0)

      {is_nil(nonce), nonce || index, -priority, index}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Returns MEV-protection execution hints for an agent or broadcaster.
  """
  @spec mev_protection_plan(keyword() | map()) :: map()
  def mev_protection_plan(opts \\ %{}) do
    %{
      private_relay: option(opts, :private_relay, true),
      simulate_before_send: option(opts, :simulate_before_send, true),
      enforce_deadline: option(opts, :enforce_deadline, true),
      max_slippage_bps: option(opts, :max_slippage_bps, 50),
      replacement_bump_bps: option(opts, :replacement_bump_bps, @default_bump_bps),
      notes: [
        "Prefer private relay submission for swap-like transactions.",
        "Simulate immediately before signing and broadcasting.",
        "Use explicit deadlines and slippage ceilings on DEX calls.",
        "Bump replacement fees by at least 12.5% unless chain policy requires more."
      ]
    }
  end

  defp bump_transaction(tx, opts) do
    bump_bps = opts[:bump_bps] || @default_bump_bps

    cond do
      Map.has_key?(tx, :max_fee_per_gas) and Map.has_key?(tx, :max_priority_fee_per_gas) ->
        with {:ok, max_fee} <- fetch_wei(tx, :max_fee_per_gas),
             {:ok, priority_fee} <- fetch_wei(tx, :max_priority_fee_per_gas) do
          {:ok,
           tx
           |> Map.put(:max_fee_per_gas, bump_wei(max_fee, bump_bps))
           |> Map.put(:max_priority_fee_per_gas, bump_wei(priority_fee, bump_bps))}
        end

      Map.has_key?(tx, :gas_price) ->
        with {:ok, gas_price} <- fetch_wei(tx, :gas_price) do
          {:ok, Map.put(tx, :gas_price, bump_wei(gas_price, bump_bps))}
        end

      true ->
        {:error, :missing_fee_fields}
    end
  end

  defp batch_rows(transactions, max_fee_per_gas) do
    transactions
    |> plan_batch()
    |> Enum.reduce_while({:ok, []}, fn tx, {:ok, rows} ->
      case fetch_wei(tx, :gas_limit) do
        {:ok, gas_limit} ->
          row = %{
            id: Map.get(tx, :id),
            nonce: Map.get(tx, :nonce),
            to: Map.get(tx, :to),
            gas_limit: gas_limit,
            max_cost_wei: gas_limit * max_fee_per_gas
          }

          {:cont, {:ok, [row | rows]}}

        {:error, reason} ->
          {:halt, {:error, {:invalid_transaction_gas_limit, reason, tx}}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  defp priority_samples(fee_data) do
    sample_values =
      case fetch_key(fee_data, :priority_fee_samples) do
        {:ok, values} -> values
        :error -> [2 * @gwei]
      end

    samples =
      sample_values
      |> List.wrap()
      |> Enum.map(&parse_wei/1)

    cond do
      samples == [] ->
        {:error, :empty_priority_fee_samples}

      Enum.all?(samples, &match?({:ok, _}, &1)) ->
        {:ok, Enum.map(samples, fn {:ok, value} -> value end)}

      true ->
        {:error, :invalid_priority_fee_samples}
    end
  end

  defp percentile(samples, urgency) do
    sorted = Enum.sort(samples)
    index = ceil_div((length(sorted) - 1) * urgency, 100)
    Enum.at(sorted, index)
  end

  defp urgency_percentile(:slow), do: 25
  defp urgency_percentile(:normal), do: 50
  defp urgency_percentile(:fast), do: 75
  defp urgency_percentile(_urgency), do: 50

  defp urgency_base_multiplier_bps(:slow), do: 11_000
  defp urgency_base_multiplier_bps(:normal), do: 12_500
  defp urgency_base_multiplier_bps(:fast), do: 15_000
  defp urgency_base_multiplier_bps(_urgency), do: 12_500

  defp fetch_wei(map, key) do
    map
    |> fetch_key(key)
    |> case do
      {:ok, value} -> parse_wei(value)
      :error -> {:error, {:missing, key}}
    end
  end

  defp fetch_key(map, key), do: Map.fetch(map, key) |> or_fetch(map, Atom.to_string(key))

  defp or_fetch({:ok, _value} = result, _map, _key), do: result
  defp or_fetch(:error, map, key), do: Map.fetch(map, key)

  defp option(opts, key, default) do
    case opts[key] do
      nil -> default
      value -> value
    end
  end

  defp parse_wei(value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp parse_wei("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, :invalid_hex_quantity}
    end
  end

  defp parse_wei(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed >= 0 -> {:ok, parsed}
      _ -> {:error, :invalid_wei}
    end
  end

  defp parse_wei(_value), do: {:error, :invalid_wei}

  defp bump_wei(value, bump_bps), do: ceil_div(value * (10_000 + bump_bps), 10_000)
  defp ceil_div(value, divisor), do: div(value + divisor - 1, divisor)
end
