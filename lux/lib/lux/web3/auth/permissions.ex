defmodule Lux.Web3.Auth.Permissions do
  @moduledoc """
  Role and permission policy checks for Web3-authenticated Lux sessions.
  """

  alias Lux.Web3.Auth.Session

  @type decision :: {:ok, :authorized} | {:error, String.t()}

  @spec authorize(map(), String.t(), map()) :: decision()
  def authorize(session, permission, policy \\ %{}) when is_binary(permission) do
    cond do
      not Session.active?(session) ->
        {:error, "Session has expired"}

      Session.has_permission?(session, permission) ->
        {:ok, :authorized}

      role_grants_permission?(session, permission, policy) ->
        {:ok, :authorized}

      true ->
        {:error, "Missing required permission #{permission}"}
    end
  end

  @spec authorize_any(map(), [String.t()], map()) :: decision()
  def authorize_any(session, permissions, policy \\ %{}) when is_list(permissions) do
    if Enum.any?(permissions, fn permission -> authorize(session, permission, policy) == {:ok, :authorized} end) do
      {:ok, :authorized}
    else
      {:error, "Missing one of required permissions: #{Enum.join(permissions, ", ")}"}
    end
  end

  @spec authorize_all(map(), [String.t()], map()) :: decision()
  def authorize_all(session, permissions, policy \\ %{}) when is_list(permissions) do
    case Enum.find(permissions, fn permission -> authorize(session, permission, policy) != {:ok, :authorized} end) do
      nil -> {:ok, :authorized}
      permission -> {:error, "Missing required permission #{permission}"}
    end
  end

  defp role_grants_permission?(%{roles: roles}, permission, %{roles: role_policy}) do
    Enum.any?(roles, fn role ->
      grants = Map.get(role_policy, role, [])
      permission in grants or "*" in grants
    end)
  end

  defp role_grants_permission?(_, _, _), do: false
end
