defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control (RBAC) and permission management for Web3 accounts.

  Provides built-in hierarchical roles (`:admin`, `:operator`, `:trader`, `:viewer`),
  custom role registration, address-to-role bindings, and fine-grained permission
  evaluation.
  """

  @roles_table :lux_web3_auth_roles
  @assignments_table :lux_web3_auth_role_assignments

  @default_roles %{
    admin: [
      :manage_roles,
      :manage_wallets,
      :execute_trades,
      :deploy_contracts,
      :configure_agents,
      :read_analytics
    ],
    operator: [
      :manage_wallets,
      :execute_trades,
      :configure_agents,
      :read_analytics
    ],
    trader: [
      :execute_trades,
      :read_analytics
    ],
    viewer: [
      :read_analytics
    ]
  }

  @doc """
  Initializes ETS tables for roles and address assignments.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@roles_table)
    ensure_table(@assignments_table)

    if :ets.info(@roles_table, :size) == 0 do
      seed_defaults()
    end

    :ok
  end

  @doc """
  Resets roles and address role assignments to defaults.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@roles_table)
    :ets.delete_all_objects(@assignments_table)
    seed_defaults()
  end

  @doc """
  Defines or updates a role with a list of granted permissions.
  """
  @spec define_role(atom(), [atom()]) :: :ok
  def define_role(role, permissions) when is_atom(role) and is_list(permissions) do
    ensure_started()
    :ets.insert(@roles_table, {role, Enum.uniq(permissions)})
    :ok
  end

  @doc """
  Assigns a role to an Ethereum address.
  """
  @spec assign_role(String.t(), atom()) :: :ok
  def assign_role(address, role) when is_binary(address) and is_atom(role) do
    ensure_started()
    key = String.downcase(address)
    current = get_roles(key)
    :ets.insert(@assignments_table, {key, Enum.uniq([role | current])})
    :ok
  end

  @doc """
  Revokes a role from an Ethereum address.
  """
  @spec revoke_role(String.t(), atom()) :: :ok
  def revoke_role(address, role) when is_binary(address) and is_atom(role) do
    ensure_started()
    key = String.downcase(address)
    updated = List.delete(get_roles(key), role)
    :ets.insert(@assignments_table, {key, updated})
    :ok
  end

  @doc """
  Returns all roles assigned to an Ethereum address.
  """
  @spec get_roles(String.t()) :: [atom()]
  def get_roles(address) when is_binary(address) do
    ensure_started()
    key = String.downcase(address)

    case :ets.lookup(@assignments_table, key) do
      [{^key, roles}] -> roles
      [] -> []
    end
  end

  @doc """
  Returns all effective permissions granted to an Ethereum address across its assigned roles.
  """
  @spec get_permissions(String.t()) :: [atom()]
  def get_permissions(address) when is_binary(address) do
    ensure_started()

    address
    |> get_roles()
    |> Enum.flat_map(fn role ->
      case :ets.lookup(@roles_table, role) do
        [{^role, perms}] -> perms
        [] -> []
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Returns true if `address` holds the given `permission`.
  """
  @spec has_permission?(String.t(), atom()) :: boolean()
  def has_permission?(address, permission) when is_binary(address) and is_atom(permission) do
    permission in get_permissions(address)
  end

  defp seed_defaults do
    Enum.each(@default_roles, fn {role, perms} ->
      :ets.insert(@roles_table, {role, perms})
    end)

    :ok
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
