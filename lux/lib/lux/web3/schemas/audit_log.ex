defmodule Lux.Web3.Schemas.AuditLog do
  @moduledoc """
  Audit log entry for tracking all authentication events.

  Records every auth-related action: login attempts, signature verifications,
  permission changes, session creation/revocation, and token-gate evaluations.
  """

  @type action ::
          :login_attempt
          | :login_success
          | :login_failure
          | :signature_verified
          | :signature_failed
          | :session_created
          | :session_expired
          | :session_revoked
          | :permission_granted
          | :permission_revoked
          | :role_assigned
          | :role_removed
          | :token_gate_evaluated
          | :multisig_approved
          | :multisig_rejected

  @type t :: %__MODULE__{
          id: String.t(),
          action: action(),
          address: String.t(),
          timestamp: String.t(),
          details: map(),
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          success: boolean()
        }

  defstruct [
    :id,
    :action,
    :address,
    :timestamp,
    details: %{},
    ip_address: nil,
    user_agent: nil,
    success: true
  ]

  @doc """
  Create a new audit log entry.
  """
  @spec create(action :: action(), address :: String.t(), details :: map()) :: t()
  def create(action, address, details \ %{}) do
    %__MODULE__{
      id: :crypto.strong_rand_bytes(11) |> Base.encode16(case: :lower),
      action: action,
      address: String.downcase(address),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      details: details,
      success: action in [:login_success, :signature_verified, :multisig_approved]
    }
  end

  @doc """
  Serialize the audit log entry to a map for storage.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = entry) do
    Map.from_struct(entry)
  end

  @doc """
  Build a human-readable summary of the audit log entry.
  """
  @spec summary(t()) :: String.t()
  def summary(%__MODULE__{action: action, address: addr, details: details}) do
    "#{action} for #{addr}: #{format_details(details)}"
  end

  defp format_details(%{reason: reason}), do: "reason: #{reason}"
  defp format_details(%{message: msg}), do: "message: #{msg}"
  defp format_details(%{required: required, actual: actual}), do: "#{required} vs #{actual}"
  defp format_details(_), do: "(no details)"
end
