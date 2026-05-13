defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-based access control helpers for wallet addresses and sessions.
  """

  alias Lux.Web3.Auth.Signature

  @type permission :: %{action: atom() | String.t(), resource: atom() | String.t()}
  @type policy :: %{roles: map(), assignments: map()}

  @doc """
  Creates an empty RBAC policy.
  """
  @spec new() :: policy()
  def new, do: %{roles: %{}, assignments: %{}}

  @doc """
  Defines or replaces a role's permissions.
  """
  @spec put_role(policy(), atom() | String.t(), [permission()]) :: policy()
  def put_role(policy, role, permissions) when is_list(permissions) do
    put_in(policy, [:roles, role], Enum.map(permissions, &normalize_permission/1))
  end

  @doc """
  Grants a role to a wallet address.
  """
  @spec grant_role(policy(), String.t(), atom() | String.t()) :: policy()
  def grant_role(policy, address, role) do
    normalized = Signature.normalize_address(address)

    update_in(policy, [:assignments, normalized], fn roles ->
      [role | roles || []] |> Enum.uniq()
    end)
  end

  @doc """
  Revokes a role from a wallet address.
  """
  @spec revoke_role(policy(), String.t(), atom() | String.t()) :: policy()
  def revoke_role(policy, address, role) do
    normalized = Signature.normalize_address(address)

    update_in(policy, [:assignments, normalized], fn roles ->
      Enum.reject(roles || [], &(&1 == role))
    end)
  end

  @doc """
  Returns all roles assigned to an address.
  """
  @spec roles_for(policy(), String.t()) :: [atom() | String.t()]
  def roles_for(policy, address) do
    get_in(policy, [:assignments, Signature.normalize_address(address)]) || []
  end

  @doc """
  Checks whether an address or session has a permission.
  """
  @spec authorized?(policy(), String.t() | map(), atom() | String.t(), atom() | String.t()) ::
          boolean()
  def authorized?(policy, subject, action, resource) do
    roles =
      case subject do
        address when is_binary(address) -> roles_for(policy, address)
        %{roles: roles} when is_list(roles) -> roles
        %{"roles" => roles} when is_list(roles) -> roles
        _ -> []
      end

    Enum.any?(roles, fn role ->
      policy
      |> get_in([:roles, role])
      |> List.wrap()
      |> Enum.any?(&permission_matches?(&1, action, resource))
    end)
  end

  defp normalize_permission(permission) when is_map(permission) do
    %{
      action: Map.get(permission, :action) || Map.get(permission, "action"),
      resource: Map.get(permission, :resource) || Map.get(permission, "resource")
    }
  end

  defp normalize_permission({action, resource}), do: %{action: action, resource: resource}
  defp normalize_permission(:all), do: %{action: :*, resource: :*}

  defp permission_matches?(permission, action, resource) do
    value_matches?(permission.action, action) and value_matches?(permission.resource, resource)
  end

  defp value_matches?(:*, _value), do: true
  defp value_matches?("*", _value), do: true
  defp value_matches?(expected, value), do: to_string(expected) == to_string(value)
end
