defmodule Lux.Web3.Auth do
  @moduledoc """
  High-level Web3 authentication and authorization workflow helpers.
  """

  alias Lux.Web3.Auth.{RBAC, SIWE, Session, TokenGate}

  @doc """
  Authenticates a SIWE message/signature pair and issues a session.
  """
  @spec sign_in(String.t(), String.t() | binary(), keyword() | map()) ::
          {:ok, map()} | {:error, term()}
  def sign_in(message, signature, opts \\ %{}) do
    with {:ok, siwe} <- SIWE.authenticate(message, signature, opts),
         :ok <- authorize_token_gates(opts) do
      session =
        Session.issue(siwe.address,
          now: option(opts, :now, DateTime.utc_now()),
          ttl_seconds: option(opts, :ttl_seconds, 3_600),
          roles: option(opts, :roles, []),
          permissions: option(opts, :permissions, [])
        )

      {:ok, %{siwe: siwe, session: session}}
    end
  end

  @doc """
  Checks role/permission authorization for an active session.
  """
  @spec authorize_session(
          map(),
          RBAC.policy(),
          atom() | String.t(),
          atom() | String.t(),
          keyword() | map()
        ) ::
          :ok | {:error, term()}
  def authorize_session(session, policy, action, resource, opts \\ %{}) do
    now = option(opts, :now, DateTime.utc_now())

    cond do
      Session.expired?(session, now) ->
        {:error, :session_expired}

      RBAC.authorized?(policy, session, action, resource) ->
        :ok

      true ->
        {:error, :unauthorized}
    end
  end

  defp authorize_token_gates(opts) do
    rules = option(opts, :token_gates, [])
    holdings = option(opts, :holdings, %{})

    if rules == [] or TokenGate.allowed?(holdings, rules) do
      :ok
    else
      {:error, :token_gate_failed}
    end
  end

  defp option(opts, key, default) when is_map(opts),
    do: Map.get(opts, key) || Map.get(opts, to_string(key), default)

  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)
  defp option(_opts, _key, default), do: default
end
