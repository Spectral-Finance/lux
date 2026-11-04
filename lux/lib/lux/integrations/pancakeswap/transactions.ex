defmodule Lux.Integrations.PancakeSwap.Transactions do
  @moduledoc """
  Builders for unsigned PancakeSwap transaction requests.

  A step is a plain map `%{name, chain_id, to, data, value}` that any wallet or signer
  can turn into a transaction. `value` is the native token amount in wei, as a string.
  """

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Lux.Integrations.PancakeSwap.Codec

  @type step :: %{
          name: String.t(),
          chain_id: pos_integer(),
          to: String.t(),
          data: String.t(),
          value: String.t()
        }

  @doc """
  Builds an unsigned transaction step for a contract call.

  Raises `ArgumentError` if an argument does not match the signature.
  """
  @spec step(
          String.t(),
          PancakeSwap.chain(),
          String.t(),
          String.t(),
          [term()],
          non_neg_integer()
        ) :: step()
  def step(name, chain, to, signature, args, value \\ 0) do
    %{
      name: name,
      chain_id: chain.id,
      to: to,
      data: signature |> Codec.encode_call(args) |> Codec.to_hex(),
      value: Integer.to_string(value)
    }
  end

  @doc """
  Returns `{:ok, [approve_step]}` when the current allowance of `owner` for `spender` is
  below `amount`, and `{:ok, []}` when it is already sufficient.
  """
  @spec approval_steps(
          PancakeSwap.chain(),
          String.t(),
          String.t(),
          String.t(),
          non_neg_integer(),
          keyword()
        ) :: {:ok, [step()]} | {:error, String.t()}
  def approval_steps(chain, token, owner, spender, amount, opts \\ []) do
    case Client.allowance(chain, token, owner, spender, opts) do
      {:ok, allowance} when allowance >= amount ->
        {:ok, []}

      {:ok, _allowance} ->
        {:ok, [step("approve", chain, token, "approve(address,uint256)", [spender, amount])]}

      {:error, reason} ->
        {:error, "Failed to read allowance: #{PancakeSwap.format_error(reason)}"}
    end
  end

  @doc """
  Runs `fun`, converting an `ArgumentError` raised while encoding into `{:error, message}`.
  """
  @spec safe((-> {:ok, term()} | {:error, String.t()})) :: {:ok, term()} | {:error, String.t()}
  def safe(fun) do
    fun.()
  rescue
    error in ArgumentError -> {:error, Exception.message(error)}
  end
end
