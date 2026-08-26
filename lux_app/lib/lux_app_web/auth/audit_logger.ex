defmodule LuxAppWeb.Auth.AuditLogger do
  @moduledoc """
  Structured audit logging for authentication, session management, and token-gating.

  ## Examples

      LuxAppWeb.Auth.AuditLogger.log_login_success("0x123...", 1)
      LuxAppWeb.Auth.AuditLogger.log_login_failure("domain.com", :expired_message)
      LuxAppWeb.Auth.AuditLogger.log_session_event("0x123...", :session_expired)
  """
  require Logger

  @doc """
  Logs successful authentication events.
  """
  def log_login_success(address, chain_id) do
    Logger.info("[AUTH_AUDIT] Success: address=#{address} chain_id=#{chain_id}")
  end

  @doc """
  Logs authentication failures with detailed failure reason.
  """
  def log_login_failure(identifier, reason) do
    Logger.warning("[AUTH_AUDIT] Failure: identifier=#{identifier} reason=#{inspect(reason)}")
  end

  @doc """
  Logs session events (e.g. expiration, renewal, logout).
  """
  def log_session_event(address, event_type) do
    Logger.info("[AUTH_AUDIT] SessionEvent: address=#{address} type=#{event_type}")
  end

  @doc """
  Logs token-gating access decisions.
  """
  def log_token_gate(address, granted?) do
    status = if granted?, do: "GRANTED", else: "DENIED"
    Logger.info("[AUTH_AUDIT] TokenGate: address=#{address} status=#{status}")
  end
end
