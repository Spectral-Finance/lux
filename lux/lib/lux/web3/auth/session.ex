defmodule Lux.Web3.Auth.Session do
  @moduledoc """
  Stateless session objects for authenticated Web3 principals.

  Lux callers can persist the returned session maps in their own storage or pass
  them directly through agent context.
  """

  alias Lux.Web3.Auth.Siwe

  @default_ttl_seconds 3_600

  @spec create(Siwe.t(), keyword()) :: map()
  def create(%{} = siwe, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now()) |> DateTime.truncate(:second)
    ttl_seconds = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)
    expires_at = Keyword.get(opts, :expires_at, DateTime.add(now, ttl_seconds, :second))
    roles = Keyword.get(opts, :roles, [])
    permissions = Keyword.get(opts, :permissions, [])

    %{
      id: session_id(siwe, now),
      address: siwe.address,
      domain: siwe.domain,
      uri: siwe.uri,
      chain_id: siwe.chain_id,
      nonce: siwe.nonce,
      resources: siwe.resources,
      roles: normalize_list(roles),
      permissions: normalize_list(permissions),
      issued_at: now,
      expires_at: expires_at,
      authenticated_at: now
    }
  end

  @spec active?(map(), DateTime.t()) :: boolean()
  def active?(%{expires_at: expires_at}, now \\ DateTime.utc_now()) do
    DateTime.compare(now, expires_at) == :lt
  end

  @spec has_permission?(map(), String.t()) :: boolean()
  def has_permission?(%{permissions: permissions}, permission) when is_binary(permission) do
    permission in permissions or "*" in permissions
  end

  def has_permission?(_, _), do: false

  @spec has_role?(map(), String.t()) :: boolean()
  def has_role?(%{roles: roles}, role) when is_binary(role), do: role in roles
  def has_role?(_, _), do: false

  defp session_id(siwe, now) do
    :crypto.hash(:sha256, "#{siwe.domain}:#{siwe.address}:#{siwe.nonce}:#{DateTime.to_iso8601(now)}")
    |> Base.url_encode64(padding: false)
  end

  defp normalize_list(values) when is_list(values), do: Enum.map(values, &to_string/1)
  defp normalize_list(nil), do: []
  defp normalize_list(value), do: [to_string(value)]
end
