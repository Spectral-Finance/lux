defmodule Lux.Web3.Auth.AuditLog do
  @moduledoc """
  Structured audit events for Web3 authentication and authorization flows.
  """

  @redacted_keys [:signature, :private_key, :token, "signature", "private_key", "token"]

  @spec event(atom() | String.t(), map(), atom() | String.t(), map()) :: map()
  def event(action, subject, result, metadata \\ %{}) do
    %{
      action: to_string(action),
      result: to_string(result),
      subject: %{
        address: Map.get(subject, :address) || Map.get(subject, "address"),
        domain: Map.get(subject, :domain) || Map.get(subject, "domain"),
        chain_id: Map.get(subject, :chain_id) || Map.get(subject, "chain_id")
      },
      metadata: redact(metadata),
      timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  @spec redact(map()) :: map()
  def redact(metadata) when is_map(metadata) do
    Map.new(metadata, fn
      {key, _value} when key in @redacted_keys -> {key, "[REDACTED]"}
      {key, value} when is_map(value) -> {key, redact(value)}
      pair -> pair
    end)
  end

  def redact(_), do: %{}
end
