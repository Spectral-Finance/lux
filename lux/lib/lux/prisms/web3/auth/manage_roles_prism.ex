defmodule Lux.Prisms.Web3.Auth.ManageRolesPrism do
  @moduledoc """
  A prism for managing roles in the Web3 RBAC system.

  Supports operations:
  - `assign` - Assign a role to an address
  - `revoke` - Remove a role from an address
  - `check` - Check if an address has a specific permission
  - `list` - List roles for an address

  ## Examples

      iex> ManageRolesPrism.handler(%{
      ...>   action: "assign",
      ...>   address: "0x71C7656EC7ab88b098defB751B7401B5f6d8976F",
      ...>   role: "operator"
      ...> }, %{})
      {:ok, %{success: true, action: "assign", role: :operator}}
  """

  use Lux.Prism,
    name: "Manage Web3 Roles",
    description: "Manages roles and permissions in the Web3 RBAC system",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: assign, revoke, check, or list",
          enum: ["assign", "revoke", "check", "list"]
        },
        address: %{
          type: :string,
          description: "The Ethereum address"
        },
        role: %{
          type: :string,
          description: "The role name (for assign/revoke)"
        },
        permission: %{
          type: :string,
          description: "The permission to check (for check action, e.g., 'agents:read')"
        }
      },
      required: ["action", "address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        action: %{type: :string},
        roles: %{type: :array, description: "List of roles (for list action)"},
        has_permission: %{type: :boolean, description: "Permission check result"}
      },
      required: ["success"]
    }

  alias Lux.Web3.Auth.RBAC

  require Logger

  @impl true
  def handler(%{action: "assign", address: address, role: role}, _ctx) do
    role_atom = String.to_existing_atom(role)

    case RBAC.assign_role(address, role_atom) do
      :ok ->
        Logger.info("Role #{role} assigned to #{address}")
        {:ok, %{success: true, action: "assign", role: role_atom, address: address}}

      {:error, reason} ->
        {:ok, %{success: false, action: "assign", error: reason}}
    end
  rescue
    ArgumentError ->
      {:ok, %{success: false, action: "assign", error: "unknown role: #{role}"}}
  end

  def handler(%{action: "revoke", address: address, role: role}, _ctx) do
    role_atom = String.to_existing_atom(role)
    RBAC.revoke_role(address, role_atom)
    Logger.info("Role #{role} revoked from #{address}")
    {:ok, %{success: true, action: "revoke", role: role_atom, address: address}}
  rescue
    ArgumentError ->
      {:ok, %{success: false, action: "revoke", error: "unknown role: #{role}"}}
  end

  def handler(%{action: "check", address: address, permission: permission}, _ctx) do
    has_perm = RBAC.has_permission?(address, permission)
    {:ok, %{success: true, action: "check", has_permission: has_perm, permission: permission}}
  end

  def handler(%{action: "list", address: address}, _ctx) do
    roles = RBAC.get_roles(address)
    {:ok, %{success: true, action: "list", roles: roles, address: address}}
  end

  def handler(_params, _ctx) do
    {:error, "Invalid parameters. Required: action (assign|revoke|check|list), address"}
  end
end
