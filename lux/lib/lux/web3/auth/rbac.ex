defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control for Web3 authenticated users.

  Provides a flexible RBAC system supporting hierarchical roles,
  fine-grained permissions, and address-scoped role assignments.
  Roles are stored in ETS for high-throughput access patterns.
  """

  require Logger

  @typedoc "Permission definition"
  @type permission :: atom() | String.t()

  @typedoc "Role definition"
  @type role :: %{
          required(:name) => atom() | String.t(),
          required(:permissions) => [permission()],
          optional(:inherits) => [atom() | String.t()]
        }

  @typedoc "Role assignment"
  @type assignment :: %{
          required(:address) => String.t(),
          required(:role) => atom() | String.t(),
          optional(:scope) => String.t() | nil
        }

  @ets_roles :lux_web3_roles
  @ets_assignments :lux_web3_role_assignments

  @default_roles [
    %{name: :admin, permissions: [:all], inherits: [:manager, :trader]},
    %{name: :manager, permissions: [:manage_users, :manage_contracts, :view_analytics],
      inherits: [:trader]},
    %{name: :trader, permissions: [:execute_trades, :view_positions, :view_markets],
      inherits: [:viewer]},
    %{name: :viewer, permissions: [:view_dashboard, :view_positions, :view_markets],
      inherits: []}
  ]

  @doc """
  Initializes the RBAC ETS stores and seeds default roles.
  """
  @spec init_store() :: :ok
  def init_store do
    unless :ets.whereis(@ets_roles) != :undefined do
      :ets.new(@ets_roles, [:named_table, :public, :set,
        read_concurrency: true, write_concurrency: true])
    end

    unless :ets.whereis(@ets_assignments) != :undefined do
      :ets.new(@ets_assignments, [:named_table, :public, :set,
        read_concurrency: true, write_concurrency: true])
    end

    seed_default_roles()
  end

  @doc """
  Registers a new role with its permissions and optional inherited roles.
  """
  @spec add_role(role()) :: :ok | {:error, String.t()}
  def add_role(%{name: name, permissions: perms} = role) when is_list(perms) do
    role_data = %{
      name: name_to_key(name),
      permissions: Enum.map(perms, &to_string/1),
      inherits: (role[:inherits] || []) |> Enum.map(&name_to_key/1)
    }

    :ets.insert(@ets_roles, {name_to_key(name), role_data})
    :ok
  end

  @doc """
  Assigns a role to a given Ethereum address.
  """
  @spec assign_role(String.t(), atom() | String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def assign_role(address, role, scope \\ nil) do
    role_key = name_to_key(role)
    addr = String.downcase(address)
    key = {addr, role_key, scope}

    unless role_exists?(role_key) do
      {:error, "Role not found: #{role}"}
    else
      :ets.insert(@ets_assignments, {key, %{address: addr, role: role_key, scope: scope}})
      :ok
    end
  end

  @doc """
  Removes a role assignment from an address.
  """
  @spec revoke_role(String.t(), atom() | String.t(), String.t() | nil) :: :ok
  def revoke_role(address, role, scope \\ nil) do
    role_key = name_to_key(role)
    addr = String.downcase(address)
    key = {addr, role_key, scope}
    :ets.delete(@ets_assignments, key)
    :ok
  end

  @doc """
  Gets all roles assigned to an address.
  """
  @spec get_roles(String.t()) :: [atom()]
  def get_roles(address) do
    addr = String.downcase(address)

    @ets_assignments
    |> :ets.tab2list()
    |> Enum.filter(fn {{a, _role, _scope}, _} -> a == addr end)
    |> Enum.map(fn {{_a, role, _scope}, _} -> String.to_atom(role) end)
    |> Enum.uniq()
  end

  @doc """
  Checks if an address has a specific permission.
  Walks the role hierarchy including inherited roles.
  """
  @spec has_permission?(String.t(), permission()) :: boolean()
  def has_permission?(address, permission) do
    perm_str = to_string(permission)

    address
    |> get_roles()
    |> Enum.any?(fn role ->
      role_key = name_to_key(role)
      role_data = :ets.lookup(@ets_roles, role_key)
      role_has_permission?(role_data, perm_str, [])
    end)
  end

  @doc """
  Checks if an address has a specific role (directly or through inheritance).
  """
  @spec has_role?(String.t(), atom() | String.t()) :: boolean()
  def has_role?(address, role) do
    role_key = name_to_key(role)
    address
    |> get_roles()
    |> Enum.any?(fn r ->
      name_to_key(r) == role_key or inherited_role?(name_to_key(r), role_key, [])
    end)
  end

  @doc """
  Returns all effective permissions for an address.
  """
  @spec get_permissions(String.t()) :: [String.t()]
  def get_permissions(address) do
    address
    |> get_roles()
    |> Enum.flat_map(fn role ->
      case :ets.lookup(@ets_roles, name_to_key(role)) do
        [{_key, data}] ->
          collect_permissions(data, [])

        [] ->
          []
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Lists all registered roles.
  """
  @spec list_roles() :: [map()]
  def list_roles do
    @ets_roles
    |> :ets.tab2list()
    |> Enum.map(fn {_key, data} -> data end)
  end

  @doc """
  Lists all role assignments.
  """
  @spec list_assignments() :: [assignment()]
  def list_assignments do
    @ets_assignments
    |> :ets.tab2list()
    |> Enum.map(fn {_key, data} -> data end)
  end

  defp seed_default_roles do
    Enum.each(@default_roles, &add_role/1)
  end

  defp role_exists?(role_key) do
    case :ets.lookup(@ets_roles, role_key) do
      [] -> false
      [{^role_key, _}] -> true
    end
  end

  defp role_has_permission?([], _perm, _visited), do: false

  defp role_has_permission?([{_key, data}], perm, visited) do
    if perm in visited do
      false
    else
      has_direct = perm in data.permissions or "all" in data.permissions

      has_direct or
        Enum.any?(data.inherits, fn parent ->
          parent_data = :ets.lookup(@ets_roles, parent)
          role_has_permission?(parent_data, perm, [perm | visited])
        end)
    end
  end

  defp inherited_role?(role_key, target_key, visited) do
    if role_key in visited do
      false
    else
      case :ets.lookup(@ets_roles, role_key) do
        [{^role_key, data}] ->
          target_key in data.inherits or
            Enum.any?(data.inherits, fn parent ->
              inherited_role?(parent, target_key, [role_key | visited])
            end)

        [] ->
          false
      end
    end
  end

  defp collect_permissions(data, visited) do
    if data.name in visited do
      []
    else
      data.permissions ++
        Enum.flat_map(data.inherits, fn parent ->
          case :ets.lookup(@ets_roles, parent) do
            [{_k, parent_data}] ->
              collect_permissions(parent_data, [data.name | visited])

            [] ->
              []
          end
        end)
    end
  end

  defp name_to_key(name) when is_atom(name), do: Atom.to_string(name)
  defp name_to_key(name) when is_binary(name), do: name
end
