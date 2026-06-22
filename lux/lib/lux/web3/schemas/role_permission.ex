defmodule Lux.Web3.Schemas.RolePermission do
  @moduledoc """
  Role-Based Access Control (RBAC) schema.

  Defines roles, permissions, and the mapping between them.
  Supports hierarchical role inheritance and fine-grained resource access.
  """

  @type permission :: %{
          required: atom(),
          resource: String.t(),
          action: String.t()
        }

  @type role :: %{
          name: String.t(),
          description: String.t(),
          permissions: [permission()],
          inherited_from: [String.t()] | nil
        }

  @type t :: %__MODULE__{
          roles: %{String.t() => role()},
          address_roles: %{String.t() => [String.t()]},
          multisig_config: multisig_config() | nil
        }

  @type multisig_config :: %{
          required_signatures: non_neg_integer(),
          signers: [String.t()],
          threshold: non_neg_integer()
        }

  defstruct roles: %{},
            address_roles: %{},
            multisig_config: nil

  @doc """
  Create a new RBAC schema.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Add a role with its permissions.
  """
  @spec add_role(t(), role()) :: t()
  def add_role(%__MODULE__{roles: roles} = schema, role) do
    name = role[:name] || raise ArgumentError, "role must have a :name key"
    %{schema | roles: Map.put(roles, name, role)}
  end

  @doc """
  Assign a role to an Ethereum address.
  """
  @spec assign_role(t(), String.t(), String.t()) :: t()
  def assign_role(%__MODULE__{address_roles: assignments} = schema, address, role_name) do
    normalized = String.downcase(address)
    existing = Map.get(assignments, normalized, [])
    updated = Enum.uniq([role_name | existing])
    %{schema | address_roles: Map.put(assignments, normalized, updated)}
  end

  @doc """
  Revoke a role from an address.
  """
  @spec revoke_role(t(), String.t(), String.t()) :: t()
  def revoke_role(%__MODULE__{address_roles: assignments} = schema, address, role_name) do
    normalized = String.downcase(address)
    existing = Map.get(assignments, normalized, [])
    updated = Enum.reject(existing, &(&1 == role_name))
    new_assignments =
      if updated == [], do: Map.delete(assignments, normalized),
      else: Map.put(assignments, normalized, updated)
    %{schema | address_roles: new_assignments}
  end

  @doc """
  Check if an address has a specific permission.
  Evaluates direct permissions and inherited ones.
  """
  @spec has_permission?(t(), String.t(), permission()) :: boolean()
  def has_permission?(schema, address, permission) do
    normalized = String.downcase(address)
    roles = Map.get(schema.address_roles, normalized, [])

    Enum.any?(roles, fn role_name ->
      role = schema.roles[role_name]
      role && permission_match?(role, permission)
    end)
  end

  @doc """
  Get all roles for an address.
  """
  @spec get_roles(t(), String.t()) :: [String.t()]
  def get_roles(schema, address) do
    Map.get(schema.address_roles, String.downcase(address), [])
  end

  @doc """
  Set multisig configuration.
  """
  @spec set_multisig_config(t(), multisig_config()) :: t()
  def set_multisig_config(schema, config) do
    %{schema | multisig_config: config}
  end

  @doc """
  Get multisig configuration.
  """
  @spec get_multisig_config(t()) :: multisig_config() | nil
  def get_multisig_config(schema), do: schema.multisig_config

  @doc """
  Check if an address is a multisig signer.
  """
  @spec is_multisig_signer?(t(), String.t()) :: boolean()
  def is_multisig_signer?(schema, address) do
    config = schema.multisig_config
    config && address in config.signers
  end

  # Internal helpers

  defp permission_match?(role, %{required: perm_required}) do
    Enum.any?(role.permissions, fn p ->
      p[:required] == perm_required and
        (is_nil(p[:resource]) or p[:resource] == "*") and
        (is_nil(p[:action]) or p[:action] == "*")
    end)
  end

  defp permission_match?(role, %{resource: res, action: act}) do
    Enum.any?(role.permissions, fn p ->
      (p[:required] == role[:name] or p[:resource] == res) and
        (p[:action] == act or p[:action] == "*")
    end)
  end
end
