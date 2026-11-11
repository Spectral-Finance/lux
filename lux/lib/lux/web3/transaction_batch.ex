defmodule Lux.Web3.TransactionBatch do
  @moduledoc """
  Encodes atomic, zero-value Multicall3 `aggregate3` transactions.

  Multicall changes `msg.sender` at each target to the Multicall contract.
  Callers must explicitly acknowledge that with `allow_sender_change: true`.
  Never use this for sender-dependent operations or token approvals. Calls
  remain in input order and every failure reverts the entire batch.
  """

  alias Lux.Web3.Gas

  @doc "Builds calldata for independent calls at a caller-verified Multicall3 deployment."
  @spec build([map()], String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def build(calls, contract, opts \\ []) do
    with true <- Keyword.get(opts, :allow_sender_change, false) == true,
         true <- Gas.address?(contract),
         true <- is_list(calls) and calls != [] and length(calls) <= 100,
         true <- Enum.all?(calls, &valid_call?/1) do
      args =
        Enum.map(calls, fn call ->
          {Ethers.Utils.hex_decode!(call["to"]), false, Ethers.Utils.hex_decode!(call["data"])}
        end)

      data = ABI.encode("aggregate3((address,bool,bytes)[])", [args])
      {:ok, %{"to" => contract, "data" => Ethers.Utils.hex_encode(data), "value" => "0x0"}}
    else
      _ -> {:error, :invalid_batch_or_sender_change_not_acknowledged}
    end
  end

  defp valid_call?(call) when is_map(call) do
    Enum.all?(Map.keys(call), &(&1 in ["to", "data", "value"])) and
      Gas.address?(call["to"]) and Gas.data?(call["data"]) and
      Gas.quantity(Map.get(call, "value", "0x0")) == {:ok, 0}
  end

  defp valid_call?(_), do: false
end
