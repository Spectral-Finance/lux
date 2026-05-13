defmodule Lux.Web3.Auth.Session do
  @moduledoc """
  Stateless session helpers with expiry and audit events.
  """

  alias Lux.Web3.Auth.Signature

  @default_ttl_seconds 3_600

  @doc """
  Issues a session for a verified wallet address.
  """
  @spec issue(String.t(), keyword() | map()) :: map()
  def issue(address, opts \\ %{}) do
    now = option(opts, :now, DateTime.utc_now())
    ttl_seconds = option(opts, :ttl_seconds, @default_ttl_seconds)
    session_id = option(opts, :id, Lux.UUID.generate())
    roles = option(opts, :roles, [])
    permissions = option(opts, :permissions, [])

    %{
      id: session_id,
      subject: Signature.normalize_address(address),
      roles: roles,
      permissions: permissions,
      issued_at: DateTime.to_iso8601(now),
      expires_at: now |> DateTime.add(ttl_seconds, :second) |> DateTime.to_iso8601(),
      revoked_at: nil,
      audit_log: [
        audit_event(:session_issued, session_id, now, %{
          subject: Signature.normalize_address(address)
        })
      ]
    }
  end

  @doc """
  Refreshes a session expiry and appends an audit event.
  """
  @spec refresh(map(), keyword() | map()) :: map()
  def refresh(session, opts \\ %{}) do
    now = option(opts, :now, DateTime.utc_now())
    ttl_seconds = option(opts, :ttl_seconds, @default_ttl_seconds)

    session
    |> Map.put(:expires_at, now |> DateTime.add(ttl_seconds, :second) |> DateTime.to_iso8601())
    |> append_audit(:session_refreshed, now)
  end

  @doc """
  Revokes a session and appends an audit event.
  """
  @spec revoke(map(), keyword() | map()) :: map()
  def revoke(session, opts \\ %{}) do
    now = option(opts, :now, DateTime.utc_now())

    session
    |> Map.put(:revoked_at, DateTime.to_iso8601(now))
    |> append_audit(:session_revoked, now)
  end

  @doc """
  Returns true when a session is expired or revoked.
  """
  @spec expired?(map(), DateTime.t()) :: boolean()
  def expired?(session, now \\ DateTime.utc_now()) do
    revoked?(session) or
      case DateTime.from_iso8601(session[:expires_at] || session["expires_at"] || "") do
        {:ok, expires_at, _offset} -> DateTime.compare(expires_at, now) != :gt
        _ -> true
      end
  end

  @doc """
  Returns true when a session is active.
  """
  @spec valid?(map(), DateTime.t()) :: boolean()
  def valid?(session, now \\ DateTime.utc_now()), do: not expired?(session, now)

  defp revoked?(session), do: not is_nil(session[:revoked_at] || session["revoked_at"])

  defp append_audit(session, event, now) do
    Map.update(session, :audit_log, [audit_event(event, session.id, now)], fn log ->
      [audit_event(event, session.id, now) | log]
    end)
  end

  defp audit_event(event, session_id, now, metadata \\ %{}) do
    %{event: event, session_id: session_id, at: DateTime.to_iso8601(now), metadata: metadata}
  end

  defp option(opts, key, default) when is_map(opts),
    do: Map.get(opts, key) || Map.get(opts, to_string(key), default)

  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)
  defp option(_opts, _key, default), do: default
end
