defmodule Lux.Web3.Gas.ReplacementManager do
  @moduledoc """
  Transaction replacement and acceleration manager.

  Implements EVM Replace-By-Fee (RBF) standards:
  - Speed-up: Ramps gas fees to unstick pending transactions while preserving payload and nonce
  - Cancel: Submits a zero-value self-transaction at the same nonce with high priority
  - RBF Compliance: Verifies the mandatory minimum 10% gas fee bump requirement
  """

  @min_rbf_bump_factor 1.10
  @default_speedup_bump 1.15
  @default_cancel_bump 1.25

  @type pending_tx :: %{
          nonce: non_neg_integer(),
          from: String.t(),
          to: String.t(),
          value: non_neg_integer(),
          data: binary(),
          max_fee_per_gas: pos_integer(),
          max_priority_fee_per_gas: pos_integer(),
          chain_id: non_neg_integer()
        }

  @doc """
  Constructs a speed-up transaction to accelerate an unconfirmed pending transaction.
  """
  @spec create_speed_up(map(), float()) :: {:ok, map()} | {:error, String.t()}
  def create_speed_up(tx, bump_multiplier \\ @default_speedup_bump) do
    with :ok <- validate_tx(tx),
         multiplier <- max(bump_multiplier, @min_rbf_bump_factor) do
      old_max_fee = get_field(tx, :max_fee_per_gas)
      old_tip = get_field(tx, :max_priority_fee_per_gas)

      new_max_fee = max(round(old_max_fee * multiplier), round(old_max_fee * @min_rbf_bump_factor) + 1)
      new_tip = max(round(old_tip * multiplier), round(old_tip * @min_rbf_bump_factor) + 1)

      accelerated_tx =
        tx
        |> put_field(:max_fee_per_gas, new_max_fee)
        |> put_field(:max_priority_fee_per_gas, new_tip)
        |> Map.put(:action, :speed_up)
        |> Map.put(:fee_bump_percentage, Float.round((multiplier - 1.0) * 100, 2))

      {:ok, accelerated_tx}
    end
  end

  @doc """
  Constructs a cancellation transaction that overwrites the pending nonce
  with a zero-value transfer back to the sender address.
  """
  @spec create_cancel(map(), float()) :: {:ok, map()} | {:error, String.t()}
  def create_cancel(tx, bump_multiplier \\ @default_cancel_bump) do
    with :ok <- validate_tx(tx) do
      from = get_field(tx, :from)
      old_max_fee = get_field(tx, :max_fee_per_gas)
      old_tip = get_field(tx, :max_priority_fee_per_gas)

      multiplier = max(bump_multiplier, @min_rbf_bump_factor)
      new_max_fee = max(round(old_max_fee * multiplier), round(old_max_fee * @min_rbf_bump_factor) + 1)
      new_tip = max(round(old_tip * multiplier), round(old_tip * @min_rbf_bump_factor) + 1)

      cancel_tx = %{
        nonce: get_field(tx, :nonce),
        from: from,
        to: from,
        value: 0,
        data: "0x",
        gas_limit: 21_000,
        max_fee_per_gas: new_max_fee,
        max_priority_fee_per_gas: new_tip,
        chain_id: get_field(tx, :chain_id, 1),
        action: :cancel,
        fee_bump_percentage: Float.round((multiplier - 1.0) * 100, 2)
      }

      {:ok, cancel_tx}
    end
  end

  @doc """
  Validates whether replacement fees comply with EVM Replace-By-Fee rules (>= 10% increase).
  """
  @spec satisfies_rbf?(pos_integer(), pos_integer()) :: boolean()
  def satisfies_rbf?(old_fee, new_fee) when is_integer(old_fee) and is_integer(new_fee) and old_fee > 0 do
    new_fee >= round(old_fee * @min_rbf_bump_factor)
  end

  defp validate_tx(tx) when is_map(tx) do
    required = [:nonce, :from, :max_fee_per_gas, :max_priority_fee_per_gas]
    missing = Enum.filter(required, fn key -> is_nil(get_field(tx, key)) end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required transaction fields: #{inspect(missing)}"}
    end
  end

  defp get_field(map, key, default \\ nil) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key), default)
  end

  defp put_field(map, key, value) do
    if Map.has_key?(map, Atom.to_string(key)) do
      Map.put(map, Atom.to_string(key), value)
    else
      Map.put(map, key, value)
    end
  end
end
