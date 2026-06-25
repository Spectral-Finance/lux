defmodule Lux.Web3.Multisig.Approval do
  @moduledoc """
  Multi-signature approval workflow.

  Manages multi-sig transaction proposals, approvals, and execution.
  Supports configurable thresholds and signer lists.
  """

  alias Lux.Web3.Schemas.AuditLog

  @type proposal :: %{
          required: atom(),
          id: String.t(),
          proposer: String.t(),
          target: String.t(),
          data: binary(),
          value: non_neg_integer(),
          signers: [String.t()],
          threshold: non_neg_integer(),
          approvals: %{String.t() => binary()},
          executed: boolean(),
          created_at: String.t()
        }

  @type config :: %{
          required: atom(),
          signers: [String.t()],
          threshold: non_neg_integer()
        }

  @doc """
  Create a new multi-sig proposal.
  """
  @spec create_proposal(config(), String.t(), String.t(), binary(), non_neg_integer()) ::
          {:ok, proposal()} | {:error, String.t()}
  def create_proposal(config, proposer, target, data, value \ 0) do
    with :ok <- validate_config(config),
         :ok <- validate_signer(config, proposer) do
      proposal = %{
        required: :proposal,
        id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
        proposer: String.downcase(proposer),
        target: target,
        data: data,
        value: value,
        signers: Enum.map(config.signers, &String.downcase/1),
        threshold: config.threshold,
        approvals: %{proposer |> String.downcase() => ""},
        executed: false,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      AuditLog.create(:multisig_approved, proposer, %{
        action: :proposal_created,
        proposal_id: proposal.id
      })

      {:ok, proposal}
    end
  end

  @doc """
  Approve a proposal with a signature.
  """
  @spec approve(proposal(), String.t(), binary()) ::
          {:ok, proposal()} | {:error, String.t()}
  def approve(%{executed: true} = proposal, _address, _signature) do
    {:error, "Proposal already executed"}
  end

  def approve(%{approvals: approvals} = proposal, address, _signature) do
    normalized = String.downcase(address)

    unless normalized in proposal.signers do
      {:error, "Address not a signer"}
    else
      if Map.has_key?(approvals, normalized) do
        {:error, "Already approved"}
      else
        new_approvals = Map.put(approvals, normalized, "")
        approval_count = Map.size(new_approvals)
        executed = approval_count >= proposal.threshold
        new_proposal = %{proposal | approvals: new_approvals, executed: executed}

        if executed do
          AuditLog.create(:multisig_approved, normalized, %{
            proposal_id: proposal.id,
            approval_count: approval_count,
            threshold: proposal.threshold
          })
        end

        {:ok, new_proposal}
      end
    end
  end

  @doc """
  Check if a proposal has reached threshold.
  """
  @spec is_approved?(proposal()) :: boolean()
  def is_approved?(%{approvals: approvals, threshold: threshold}) do
    Map.size(approvals) >= threshold
  end

  @doc """
  Get the list of approvers for a proposal.
  """
  @spec get_approvers(proposal()) :: [String.t()]
  def get_approvers(%{approvals: approvals}) do
    Map.keys(approvals)
  end

  defp validate_config(%{signers: signers, threshold: threshold})
       when is_list(signers) and length(signers) > 0 and threshold > 0 and
              threshold <= length(signers) do
    :ok
  end

  defp validate_config(_), do: {:error, "Invalid config: need signers list and threshold > 0"}

  defp validate_signer(%{signers: signers}, address) do
    if String.downcase(address) in Enum.map(signers, &String.downcase/1) do
      :ok
    else
      {:error, "Address not in signer list"}
    end
  end
end
