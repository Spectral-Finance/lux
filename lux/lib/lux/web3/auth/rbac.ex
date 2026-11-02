defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control (RBAC) and Permission Management engine for Web3.
  Provides hierarchical roles, granular permissions, address role assignments,
  and fast permission checks.
  """

  @roles_hierarchy %{
    super_admin: [:admin, :agent, :trader, :user, :guest],
    admin: [:agent, :trader, :user, :guest],
    agent: [:trader, :user, :guest],
    trader: [:user, :guest],
    user: [:guest],
    guest: []
  }

  @base_permissions %{
    guest: [:read_data],
    user: [:read_data, :call_contracts],
    trader: [:read_data, :call_contracts, :execute_trades, :manage_orders],
    agent: [:read_data, :call_contracts, :execute_trades, :manage_orders, :manage_prisms],
    admin: [
      :read_data,
      :call_contracts,
      :execute_trades,
      :manage_orders,
      :manage_prisms,
      :manage_wallets,
      :mint_tokens,
      :transfer_funds,
      :administer_users,
      :audit_logs
    ],
    super_admin: [:*]
  }

  @type role :: :super_admin | :admin | :agent | :trader | :user | :guest | atom()
  @type permission :: atom()

  @doc """
  Returns the list of all defined permissions for a specific role including inherited permissions.
  """
  @spec permissions_for_role(role()) :: list(permission())
  def permissions_for_role(:super_admin), do: [:*]

  def permissions_for_role(role) when is_atom(role) do
    inherited = Map.get(@roles_hierarchy, role, [])
    roles = [role | inherited]

    roles
    |> Enum.flat_map(fn r -> Map.get(@base_permissions, r, []) end)
    |> Enum.uniq()
  end

  @doc """
  Returns all resolved permissions for a list of roles or a user struct.
  """
  @spec permissions_for(list(role()) | map()) :: list(permission())
  def permissions_for(roles) when is_list(roles) do
    if :super_admin in roles do
      [:*]
    else
      roles
      |> Enum.flat_map(&permissions_for_role/1)
      |> Enum.uniq()
    end
  end

  def permissions_for(%{roles: roles}) when is_list(roles) do
    permissions_for(roles)
  end

  def permissions_for(%{"roles" => roles}) when is_list(roles) do
    atom_roles = Enum.map(roles, fn r -> if is_binary(r), do: String.to_atom(r), else: r end)
    permissions_for(atom_roles)
  end

  def permissions_for(_), do: permissions_for_role(:guest)

  @doc """
  Checks if a subject (roles list, user map, or address with assignments) possesses a given permission.
  """
  @spec has_permission?(list(role()) | map() | String.t(), permission(), map() | nil) :: boolean()
  def has_permission?(subject, required_permission, assignments \\ nil)

  def has_permission?(_subject, :*, _), do: true

  def has_permission?(roles, permission, _assignments) when is_list(roles) do
    perms = permissions_for(roles)
    :* in perms or permission in perms
  end

  def has_permission?(%{roles: roles}, permission, _assignments) when is_list(roles) do
    has_permission?(roles, permission)
  end

  def has_permission?(%{"roles" => roles}, permission, _assignments) when is_list(roles) do
    atom_roles = Enum.map(roles, fn r -> if is_binary(r), do: String.to_atom(r), else: r end)
    has_permission?(atom_roles, permission)
  end

  def has_permission?(address, permission, assignments) when is_binary(address) and is_map(assignments) do
    clean_addr = String.downcase(address)
    roles = Map.get(assignments, clean_addr, [:guest])
    has_permission?(roles, permission)
  end

  def has_permission?(address, permission, nil) when is_binary(address) do
    # Default to user permission set when no assignments map is provided
    has_permission?([:user], permission)
  end

  def has_permission?(_, _, _), do: false

  @doc """
  Checks if a subject has a specific role or higher hierarchy.
  """
  @spec has_role?(list(role()) | map() | String.t(), role(), map() | nil) :: boolean()
  def has_role?(subject, target_role, assignments \\ nil)

  def has_role?(roles, target_role, _assignments) when is_list(roles) do
    if :super_admin in roles do
      true
    else
      Enum.any?(roles, fn r ->
        r == target_role or target_role in Map.get(@roles_hierarchy, r, [])
      end)
    end
  end

  def has_role?(%{roles: roles}, target_role, _assignments) when is_list(roles) do
    has_role?(roles, target_role)
  end

  def has_role?(address, target_role, assignments) when is_binary(address) and is_map(assignments) do
    clean_addr = String.downcase(address)
    roles = Map.get(assignments, clean_addr, [:guest])
    has_role?(roles, target_role)
  end

  def has_role?(_, _, _), do: false

  @doc """
  Authorizes an action. Returns :ok or {:error, :unauthorized, details}.
  """
  @spec authorize(term(), permission(), map() | nil) :: :ok | {:error, :unauthorized, map()}
  def authorize(subject, required_permission, assignments \\ nil) do
    if has_permission?(subject, required_permission, assignments) do
      :ok
    else
      {:error, :unauthorized, %{required_permission: required_permission}}
    end
  end

  @doc """
  Assigns a role to an address in an assignments map.
  """
  @spec assign_role(map(), String.t(), role()) :: map()
  def assign_role(assignments, address, role) when is_map(assignments) and is_binary(address) and is_atom(role) do
    clean_addr = String.downcase(address)
    current_roles = Map.get(assignments, clean_addr, [])
    new_roles = Enum.uniq([role | current_roles])
    Map.put(assignments, clean_addr, new_roles)
  end

  @doc """
  Revokes a role from an address in an assignments map.
  """
  @spec revoke_role(map(), String.t(), role()) :: map()
  def revoke_role(assignments, address, role) when is_map(assignments) and is_binary(address) and is_atom(role) do
    clean_addr = String.downcase(address)
    current_roles = Map.get(assignments, clean_addr, [])
    new_roles = List.delete(current_roles, role)
    Map.put(assignments, clean_addr, new_roles)
  end
end
