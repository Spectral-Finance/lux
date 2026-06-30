defmodule Lux.Company.Roles do
  @moduledoc """
  Manages roles within a company.
  """

  @doc """
  Creates a new role in the company.
  """
  def create(company, role) do
    GenServer.call(company, {:create_role, role})
  end

  @doc """
  Updates an existing role in the company.
  """
  def update(company, role_id, updates) do
    GenServer.call(company, {:update_role, role_id, updates})
  end

  @doc """
  Deletes a role from the company.
  """
  def delete(company, role_id) do
    GenServer.call(company, {:delete_role, role_id})
  end

  @doc """
  Gets a role by ID.
  """
  def get(company, role_id) do
    GenServer.call(company, {:get_role, role_id})
  end

  @doc """
  Lists all roles in the company.
  """
  def list(company) do
    GenServer.call(company, :list_roles)
  end
end
