defmodule Lux.Web3.Auth.MultiSig do
  @moduledoc """
  Threshold signature checks for multi-signature wallet authentication flows.
  """

  alias Lux.Web3.Auth.Signature

  @doc """
  Verifies that at least `threshold` unique owners signed the same message.
  """
  @spec verify_threshold(String.t(), [Signature.signature()], [String.t()], pos_integer()) ::
          {:ok, map()} | {:error, term()}
  def verify_threshold(message, signatures, owners, threshold)
      when is_list(signatures) and is_list(owners) and is_integer(threshold) and threshold > 0 do
    owner_set = owners |> Enum.map(&Signature.normalize_address/1) |> MapSet.new()

    valid_signers =
      signatures
      |> Enum.reduce(MapSet.new(), fn signature, acc ->
        case Signature.recover_address(message, signature) do
          {:ok, address} ->
            normalized = Signature.normalize_address(address)
            if MapSet.member?(owner_set, normalized), do: MapSet.put(acc, normalized), else: acc

          {:error, _reason} ->
            acc
        end
      end)

    if MapSet.size(valid_signers) >= threshold do
      {:ok,
       %{
         threshold: threshold,
         valid_count: MapSet.size(valid_signers),
         valid_signers: MapSet.to_list(valid_signers)
       }}
    else
      {:error, {:threshold_not_met, MapSet.size(valid_signers)}}
    end
  end
end
