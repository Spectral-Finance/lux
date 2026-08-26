defmodule LuxAppWeb.Auth.Permissions do
  @moduledoc """
  Role-Based Access Control (RBAC) and permission management.

  ## Roles and Capabilities

  - `"admin"`: `[:read, :write, :delete, :manage_users, :token_gated_access]`
  - `"user"`: `[:read, :token_gated_access]`
  - `"guest"`: `[:read]`

  ## Examples

      # Check if role has required capability
      LuxAppWeb.Auth.Permissions.has_permission?("admin", :manage_users) #=> true
      LuxAppWeb.Auth.Permissions.has_permission?("user", :delete)        #=> false
  """

  @role_permissions %{
    "admin" => [:read, :write, :delete, :manage_users, :token_gated_access],
    "user" => [:read, :token_gated_access],
    "guest" => [:read]
  }

  @doc """
  Verifies if a given role possesses the required permission.
  """
  def has_permission?(role, required_permission) when is_binary(role) and is_atom(required_permission) do
    permissions = Map.get(@role_permissions, role, [])
    required_permission in permissions
  end
  def has_permission?(_role, _permission), do: false

  @doc """
  Authorizes an action for a given role, returning `:ok` or `{:error, :unauthorized}`.
  """
  def authorize(role, required_permission) do
    if has_permission?(role, required_permission) do
      :ok
    else
      {:error, :unauthorized}
    end
  end
end
