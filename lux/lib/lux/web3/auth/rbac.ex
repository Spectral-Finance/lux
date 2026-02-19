defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control (RBAC) for Web3-authenticated users.

  Provides a hierarchical role and permission system that integrates with
  Web3 sessions. Roles can be assigned to wallet addresses, and permissions
  can be checked against both explicit grants and role-based grants.

  ## Architecture

  Uses an ETS-based store for role definitions and address-to-role mappings.
  Supports:

  - Role hierarchy (roles can inherit permissions from parent roles)
  - Fine-grained permissions (resource:action format)
  - Wildcard permissions (`*` matches any resource or action)
  - Address-based role assignment
  - Token-gated roles (see `Lux.Web3.Auth.TokenGate`)

  ## Built-in Roles

  - `:admin` - Full access to all resources
  - `:operator` - Operational permissions (read, write, execute)
  - `:viewer` - Read-only access

  ## Examples

      iex> RBAC.start_link()
      iex> RBAC.define_role(:admin, %{permissions: ["*:*"], description: "Full access"})
      iex> RBAC.assign_role("0x71C7...", :admin)
      iex> RBAC.has_permission?("0x71C7...", "agents:create")
      true
  """

  use GenServer

  require Logger

  @type role :: atom()
  @type permission :: String.t()
  @type role_definition :: %{
          permissions: [permission()],
          parent: role() | nil,
          description: String.t()
        }

  @roles_table :lux_web3_rbac_roles
  @assignments_table :lux_web3_rbac_assignments

  @default_roles %{
    admin: %{
      permissions: ["*:*"],
      parent: nil,
      description: "Full administrative access"
    },
    operator: %{
      permissions: [
        "agents:read",
        "agents:write",
        "agents:execute",
        "beams:read",
        "beams:write",
        "beams:execute",
        "prisms:read",
        "prisms:execute",
        "lenses:read",
        "lenses:execute",
        "sessions:read"
      ],
      parent: nil,
      description: "Operational access for managing agents and workflows"
    },
    viewer: %{
      permissions: [
        "agents:read",
        "beams:read",
        "prisms:read",
        "lenses:read",
        "sessions:read"
      ],
      parent: nil,
      description: "Read-only access"
    }
  }

  # Client API

  @doc """
  Starts the RBAC manager.

  ## Options

    * `:name` - GenServer name (defaults to `#{__MODULE__}`)
    * `:default_roles` - Whether to install default roles (defaults to `true`)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Defines a new role or updates an existing one.

  ## Parameters

    * `role` - Atom identifier for the role
    * `definition` - Map with role properties:
      * `:permissions` - List of permission strings ("resource:action")
      * `:parent` - Optional parent role atom for inheritance
      * `:description` - Human-readable description
  """
  @spec define_role(role(), role_definition(), atom()) :: :ok
  def define_role(role, definition, server \\ __MODULE__) do
    GenServer.call(server, {:define_role, role, definition})
  end

  @doc """
  Removes a role definition and all its assignments.
  """
  @spec delete_role(role(), atom()) :: :ok
  def delete_role(role, server \\ __MODULE__) do
    GenServer.call(server, {:delete_role, role})
  end

  @doc """
  Returns the definition of a role.
  """
  @spec get_role(role(), atom()) :: {:ok, role_definition()} | {:error, :not_found}
  def get_role(role, server \\ __MODULE__) do
    GenServer.call(server, {:get_role, role})
  end

  @doc """
  Lists all defined roles.
  """
  @spec list_roles(atom()) :: [{role(), role_definition()}]
  def list_roles(server \\ __MODULE__) do
    GenServer.call(server, :list_roles)
  end

  @doc """
  Assigns a role to an Ethereum address.
  """
  @spec assign_role(String.t(), role(), atom()) :: :ok | {:error, String.t()}
  def assign_role(address, role, server \\ __MODULE__) do
    GenServer.call(server, {:assign_role, address, role})
  end

  @doc """
  Removes a role from an Ethereum address.
  """
  @spec revoke_role(String.t(), role(), atom()) :: :ok
  def revoke_role(address, role, server \\ __MODULE__) do
    GenServer.call(server, {:revoke_role, address, role})
  end

  @doc """
  Returns all roles assigned to an address.
  """
  @spec get_roles(String.t(), atom()) :: [role()]
  def get_roles(address, server \\ __MODULE__) do
    GenServer.call(server, {:get_roles, address})
  end

  @doc """
  Checks if an address has a specific permission.

  Resolves permissions through role hierarchy and wildcard matching.

  ## Permission Format

  Permissions follow the `"resource:action"` format:
  - `"agents:read"` - Read access to agents
  - `"agents:*"` - All actions on agents
  - `"*:read"` - Read access to all resources
  - `"*:*"` - Full access (admin)

  ## Returns

    * `true` if the address has the permission (directly or through inheritance)
    * `false` otherwise
  """
  @spec has_permission?(String.t(), permission(), atom()) :: boolean()
  def has_permission?(address, permission, server \\ __MODULE__) do
    GenServer.call(server, {:has_permission?, address, permission})
  end

  @doc """
  Returns all effective permissions for an address (including inherited ones).
  """
  @spec get_permissions(String.t(), atom()) :: [permission()]
  def get_permissions(address, server \\ __MODULE__) do
    GenServer.call(server, {:get_permissions, address})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    roles_table =
      Keyword.get(opts, :roles_table, @roles_table)

    assignments_table =
      Keyword.get(opts, :assignments_table, @assignments_table)

    ^roles_table = :ets.new(roles_table, [:named_table, :set, :public, read_concurrency: true])

    ^assignments_table =
      :ets.new(assignments_table, [:named_table, :bag, :public, read_concurrency: true])

    # Install default roles unless disabled
    if Keyword.get(opts, :default_roles, true) do
      Enum.each(@default_roles, fn {role, definition} ->
        :ets.insert(roles_table, {role, definition})
      end)
    end

    {:ok, %{roles_table: roles_table, assignments_table: assignments_table}}
  end

  @impl true
  def handle_call({:define_role, role, definition}, _from, state) do
    normalized = %{
      permissions: Map.get(definition, :permissions, []),
      parent: Map.get(definition, :parent),
      description: Map.get(definition, :description, "")
    }

    :ets.insert(state.roles_table, {role, normalized})
    Logger.info("Role defined: #{role}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:delete_role, role}, _from, state) do
    :ets.delete(state.roles_table, role)

    # Remove all assignments of this role
    ms = [{{:"$1", :"$2"}, [{:==, :"$2", role}], [:"$1"]}]

    state.assignments_table
    |> :ets.select(ms)
    |> Enum.each(fn address ->
      :ets.delete_object(state.assignments_table, {address, role})
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_role, role}, _from, state) do
    result =
      case :ets.lookup(state.roles_table, role) do
        [{^role, definition}] -> {:ok, definition}
        [] -> {:error, :not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_roles, _from, state) do
    roles =
      state.roles_table
      |> :ets.tab2list()
      |> Enum.map(fn {role, definition} -> {role, definition} end)

    {:reply, roles, state}
  end

  @impl true
  def handle_call({:assign_role, address, role}, _from, state) do
    normalized = String.downcase(address)

    case :ets.lookup(state.roles_table, role) do
      [{^role, _}] ->
        # Check if already assigned
        existing =
          state.assignments_table
          |> :ets.lookup(normalized)
          |> Enum.map(fn {_, r} -> r end)

        unless role in existing do
          :ets.insert(state.assignments_table, {normalized, role})
          Logger.info("Role #{role} assigned to #{address}")
        end

        {:reply, :ok, state}

      [] ->
        {:reply, {:error, "role #{role} does not exist"}, state}
    end
  end

  @impl true
  def handle_call({:revoke_role, address, role}, _from, state) do
    normalized = String.downcase(address)
    :ets.delete_object(state.assignments_table, {normalized, role})
    Logger.info("Role #{role} revoked from #{address}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_roles, address}, _from, state) do
    normalized = String.downcase(address)

    roles =
      state.assignments_table
      |> :ets.lookup(normalized)
      |> Enum.map(fn {_, role} -> role end)

    {:reply, roles, state}
  end

  @impl true
  def handle_call({:has_permission?, address, permission}, _from, state) do
    normalized = String.downcase(address)

    roles =
      state.assignments_table
      |> :ets.lookup(normalized)
      |> Enum.map(fn {_, role} -> role end)

    has_perm =
      Enum.any?(roles, fn role ->
        all_permissions = resolve_role_permissions(role, state.roles_table, MapSet.new())
        permission_matches?(all_permissions, permission)
      end)

    {:reply, has_perm, state}
  end

  @impl true
  def handle_call({:get_permissions, address}, _from, state) do
    normalized = String.downcase(address)

    permissions =
      state.assignments_table
      |> :ets.lookup(normalized)
      |> Enum.map(fn {_, role} -> role end)
      |> Enum.flat_map(fn role ->
        resolve_role_permissions(role, state.roles_table, MapSet.new())
        |> MapSet.to_list()
      end)
      |> Enum.uniq()

    {:reply, permissions, state}
  end

  # Private helpers

  defp resolve_role_permissions(role, table, visited) do
    if MapSet.member?(visited, role) do
      # Prevent infinite cycles
      MapSet.new()
    else
      case :ets.lookup(table, role) do
        [{^role, %{permissions: perms, parent: parent}}] ->
          own_perms = MapSet.new(perms)
          visited = MapSet.put(visited, role)

          if parent do
            parent_perms = resolve_role_permissions(parent, table, visited)
            MapSet.union(own_perms, parent_perms)
          else
            own_perms
          end

        [] ->
          MapSet.new()
      end
    end
  end

  defp permission_matches?(permission_set, requested) do
    [req_resource, req_action] = parse_permission(requested)

    Enum.any?(permission_set, fn perm ->
      [perm_resource, perm_action] = parse_permission(perm)

      (perm_resource == "*" || perm_resource == req_resource) &&
        (perm_action == "*" || perm_action == req_action)
    end)
  end

  defp parse_permission(perm) do
    case String.split(perm, ":", parts: 2) do
      [resource, action] -> [resource, action]
      [resource] -> [resource, "*"]
    end
  end
end
