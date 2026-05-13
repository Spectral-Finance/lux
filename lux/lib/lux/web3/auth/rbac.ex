defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-based authorization helpers.
  """

  @doc """
  Checks whether a session is authorized for an action/resource pair.
  """
  @spec authorized?(map(), atom(), atom(), map()) :: boolean()
  def authorized?(session, action, resource, policy) do
    session
    |> Map.get(:roles, [])
    |> Enum.any?(fn role ->
      policy
      |> Map.get(role, [])
      |> Enum.any?(&permission_matches?(&1, action, resource))
    end)
  end

  defp permission_matches?(permission, action, resource) do
    action_matches? = permission.action in [:*, action]
    resource_matches? = permission.resource in [:*, resource]
    action_matches? and resource_matches?
  end
end
