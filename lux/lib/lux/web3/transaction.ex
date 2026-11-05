defmodule Lux.Web3.Transaction do
  @moduledoc """
  Transaction building, signing and fee management for EVM chains.

  Transactions are built as EIP-1559 (type-2) payloads using the `Ethers`
  transaction primitives, with validation and ergonomic typed errors on top.

  ## Examples

      iex> {:ok, tx} = Lux.Web3.Transaction.build(%{
      ...>   chain_id: 1,
      ...>   nonce: 0,
      ...>   to: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1",
      ...>   value: 1_000_000_000_000_000_000
      ...> })
      iex> tx.value
      1000000000000000000

      iex> Lux.Web3.Transaction.build(%{chain_id: 1, to: "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"})
      {:error, :missing_nonce}
  """

  alias Ethers.Transaction, as: EthTransaction
  alias Ethers.Transaction.Eip1559
  alias Ethers.Utils
  alias Lux.Web3.Chain
  alias Lux.Web3.Wallet

  @simple_transfer_gas 21_000
  @contract_call_base_gas 50_000
  @zero_byte_gas 4
  @non_zero_byte_gas 16

  @default_priority_fee_per_gas 1_500_000_000
  @fee_multiplier 2

  @type params :: %{
          required(:chain_id) => non_neg_integer() | String.t(),
          required(:nonce) => non_neg_integer(),
          required(:to) => String.t(),
          optional(:value) => non_neg_integer(),
          optional(:input) => binary(),
          optional(:data) => binary(),
          optional(:gas) => non_neg_integer(),
          optional(:max_fee_per_gas) => non_neg_integer(),
          optional(:max_priority_fee_per_gas) => non_neg_integer(),
          optional(:base_fee_per_gas) => non_neg_integer(),
          optional(:access_list) => list(),
          optional(atom()) => term()
        }

  @doc """
  Builds a validated EIP-1559 transaction from a parameter map.

  Required keys are `:chain_id`, `:nonce` and `:to`. Fee fields default to a
  priority fee of #{@default_priority_fee_per_gas} wei and `2 * base_fee +
  priority_fee` when a base fee is supplied.
  """
  @spec build(term()) :: {:ok, Eip1559.t()} | {:error, atom()}
  def build(params) when is_map(params) do
    with :ok <- validate_required(params),
         {:ok, chain} <- Chain.get(Map.get(params, :chain_id)),
         {:ok, to} <- validate_to(Map.get(params, :to)),
         {:ok, value} <- validate_non_negative(Map.get(params, :value, 0), :invalid_amount),
         {:ok, nonce} <- validate_non_negative(Map.get(params, :nonce), :invalid_nonce),
         {:ok, input} <- validate_input(Map.get(params, :input) || Map.get(params, :data) || ""),
         {:ok, gas} <- resolve_gas(params),
         {:ok, fees} <- resolve_fees(params) do
      Eip1559.new(%{
        chain_id: chain.chain_id,
        nonce: nonce,
        to: to,
        value: value,
        input: input,
        gas: gas,
        max_fee_per_gas: fees.max_fee_per_gas,
        max_priority_fee_per_gas: fees.max_priority_fee_per_gas,
        access_list: Map.get(params, :access_list, [])
      })
    end
  end

  def build(_params), do: {:error, :invalid_transaction}

  @doc """
  Estimates the gas limit for a transaction payload.

  Plain value transfers use the intrinsic 21000 gas, contract calls include a
  per-byte cost for the payload.
  """
  @spec estimate_gas(map()) :: non_neg_integer()
  def estimate_gas(params) when is_map(params) do
    case Map.get(params, :input) || Map.get(params, :data) do
      nil -> @simple_transfer_gas
      "" -> @simple_transfer_gas
      data when is_binary(data) -> @contract_call_base_gas + data_cost(data)
      _other -> @simple_transfer_gas
    end
  end

  def estimate_gas(_params), do: @simple_transfer_gas

  @doc """
  Estimates a fee pair from a base fee.
  """
  @spec estimate_fees(term(), keyword()) :: {:ok, map()} | {:error, atom()}
  def estimate_fees(base_fee_per_gas, opts \\ []) do
    priority = Keyword.get(opts, :priority_fee_per_gas, @default_priority_fee_per_gas)
    multiplier = Keyword.get(opts, :multiplier, @fee_multiplier)

    with {:ok, base} <- validate_non_negative(base_fee_per_gas, :invalid_base_fee),
         {:ok, priority} <- validate_non_negative(priority, :invalid_priority_fee),
         {:ok, multiplier} <- validate_positive(multiplier, :invalid_multiplier) do
      {:ok,
       %{
         max_priority_fee_per_gas: priority,
         max_fee_per_gas: base * multiplier + priority
       }}
    end
  end

  @doc """
  Signs a transaction with a wallet, returning the raw signed transaction hex.
  """
  @spec sign(Eip1559.t(), Wallet.t()) :: {:ok, binary()} | {:error, atom()}
  def sign(transaction, %Wallet{} = wallet), do: Wallet.sign_transaction(transaction, wallet)

  @doc """
  Computes the transaction hash of a raw signed transaction.
  """
  @spec hash(binary()) :: binary()
  def hash("0x" <> _rest = raw_transaction) do
    raw_transaction
    |> Utils.hex_decode!()
    |> Ethers.keccak_module().hash_256()
    |> Utils.hex_encode()
  end

  @doc """
  Returns the maximum fee (in wei) a transaction may consume.
  """
  @spec total_fee(Eip1559.t()) :: non_neg_integer()
  def total_fee(%Eip1559{gas: gas, max_fee_per_gas: max_fee}), do: gas * max_fee

  @doc """
  Decodes a raw signed transaction back into its payload struct.
  """
  @spec decode(binary()) :: {:ok, EthTransaction.t()} | {:error, term()}
  def decode(raw_transaction), do: EthTransaction.decode(raw_transaction)

  defp validate_required(params) do
    cond do
      is_nil(Map.get(params, :chain_id)) -> {:error, :missing_chain_id}
      is_nil(Map.get(params, :nonce)) -> {:error, :missing_nonce}
      is_nil(Map.get(params, :to)) -> {:error, :missing_to}
      true -> :ok
    end
  end

  defp validate_to(to) when is_binary(to) do
    case Utils.decode_address(String.trim(to)) do
      {:ok, decoded} -> {:ok, Utils.encode_address!(decoded)}
      {:error, _reason} -> {:error, :invalid_address}
    end
  end

  defp validate_to(nil), do: {:error, :missing_to}
  defp validate_to(_to), do: {:error, :invalid_address}

  defp validate_input(input) when is_binary(input), do: {:ok, input}
  defp validate_input(_input), do: {:error, :invalid_input}

  defp validate_non_negative(value, _error) when is_integer(value) and value >= 0,
    do: {:ok, value}

  defp validate_non_negative(_value, error), do: {:error, error}

  defp validate_positive(value, _error) when is_integer(value) and value > 0, do: {:ok, value}
  defp validate_positive(_value, error), do: {:error, error}

  defp resolve_gas(params) do
    case Map.get(params, :gas) do
      nil -> {:ok, estimate_gas(params)}
      gas -> validate_non_negative(gas, :invalid_gas)
    end
  end

  defp resolve_fees(params) do
    base_fee = Map.get(params, :base_fee_per_gas) || 0
    provided_max = Map.get(params, :max_fee_per_gas)
    provided_priority = Map.get(params, :max_priority_fee_per_gas)
    priority = provided_priority || @default_priority_fee_per_gas

    with {:ok, defaults} <- estimate_fees(base_fee, priority_fee_per_gas: priority) do
      max_fee = provided_max || defaults.max_fee_per_gas
      validate_fee_pair(max_fee, priority, base_fee)
    end
  end

  defp validate_fee_pair(max_fee, priority, base_fee) do
    cond do
      not is_integer(max_fee) or max_fee < 0 -> {:error, :invalid_max_fee}
      not is_integer(priority) or priority < 0 -> {:error, :invalid_priority_fee}
      max_fee < priority -> {:error, :fee_too_low}
      max_fee < base_fee -> {:error, :max_fee_below_base_fee}
      true -> {:ok, %{max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority}}
    end
  end

  defp data_cost(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn
      0, acc -> acc + @zero_byte_gas
      _byte, acc -> acc + @non_zero_byte_gas
    end)
  end
end
