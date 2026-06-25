defmodule Lux.Web3.Wallet.MultiSig do
  @moduledoc "Multi-sig wallet operations."
  @spec generate_id() :: String.t()
  def generate_id, do: "msig_#{:crypto.strong_rand_bytes(12)|>Base.hex_encode32(padding:false)}"
  @spec hash_transaction(map()) :: String.t()
  def hash_transaction(tx), do: :crypto.hash(:sha256,Jason.encode!(tx))|>Base.hex_encode32(padding:false)
  @spec combine_signatures(map(), [String.t()]) :: {:ok, map()} | {:error, term()}
  def combine_signatures(tx, signers) when length(signers)>=2 do
    {:ok, Map.put(tx, :multisig_sigs, Enum.map(signers, fn s->%{signer:s,signed:true} end))}
  end
  @spec validate_threshold([map()], non_neg_integer()) :: boolean()
  def validate_threshold(approvals, t) do
    Enum.uniq(Enum.flat_map(approvals,& &1.approvals)) |> length() |> (&(&1>=t)).()
  end
end