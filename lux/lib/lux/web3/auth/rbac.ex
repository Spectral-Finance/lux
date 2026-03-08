defmodule Lux.Web3.Auth.RBAC do
  @moduledoc """
  Role-Based Access Control for Web3 addresses.

  Features:
  - Assign roles to addresses
  - Define permissions per role
  - Check authorization
  - Token-gated roles (based on token balance)
  """

  use GenServer

  defstruct [:roles, :address_roles, :token_gates]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def define_role(pid \\ __MODULE__, role, permissions) do
    GenServer.call(pid, {:define_role, role, permissions})
  end

  def assign_role(pid \\ __MODULE__, address, role) do
    GenServer.call(pid, {:assign_role, normalize(address), role})
  end

  def revoke_role(pid \\ __MODULE__, address, role) do
    GenServer.call(pid, {:revoke_role, normalize(address), role})
  end

  def get_roles(pid \\ __MODULE__, address) do
    GenServer.call(pid, {:get_roles, normalize(address)})
  end

  def has_permission?(pid \\ __MODULE__, address, permission) do
    GenServer.call(pid, {:has_permission?, normalize(address), permission})
  end

  def authorize(pid \\ __MODULE__, address, permission) do
    if has_permission?(pid, address, permission), do: :ok, else: {:error, :unauthorized}
  end

  def add_token_gate(pid \\ __MODULE__, role, contract, min_balance) do
    GenServer.call(pid, {:add_token_gate, role, normalize(contract), min_balance})
  end

  def get_token_gates(pid \\ __MODULE__) do
    GenServer.call(pid, :get_token_gates)
  end

  def list_roles(pid \\ __MODULE__) do
    GenServer.call(pid, :list_roles)
  end

  # Server

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      roles: %{},
      address_roles: %{},
      token_gates: []
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:define_role, role, permissions}, _from, state) do
    roles = Map.put(state.roles, role, MapSet.new(permissions))
    {:reply, :ok, %{state | roles: roles}}
  end

  @impl true
  def handle_call({:assign_role, address, role}, _from, state) do
    if Map.has_key?(state.roles, role) do
      addr_roles = Map.update(state.address_roles, address, MapSet.new([role]), &MapSet.put(&1, role))
      {:reply, :ok, %{state | address_roles: addr_roles}}
    else
      {:reply, {:error, :role_not_found}, state}
    end
  end

  @impl true
  def handle_call({:revoke_role, address, role}, _from, state) do
    addr_roles = Map.update(state.address_roles, address, MapSet.new(), &MapSet.delete(&1, role))
    {:reply, :ok, %{state | address_roles: addr_roles}}
  end

  @impl true
  def handle_call({:get_roles, address}, _from, state) do
    roles = Map.get(state.address_roles, address, MapSet.new()) |> MapSet.to_list()
    {:reply, {:ok, roles}, state}
  end

  @impl true
  def handle_call({:has_permission?, address, permission}, _from, state) do
    user_roles = Map.get(state.address_roles, address, MapSet.new())
    has = Enum.any?(user_roles, fn role ->
      perms = Map.get(state.roles, role, MapSet.new())
      MapSet.member?(perms, permission) || MapSet.member?(perms, :all)
    end)
    {:reply, has, state}
  end

  @impl true
  def handle_call({:add_token_gate, role, contract, min_balance}, _from, state) do
    gate = %{role: role, contract: contract, min_balance: min_balance}
    {:reply, :ok, %{state | token_gates: [gate | state.token_gates]}}
  end

  @impl true
  def handle_call(:get_token_gates, _from, state) do
    {:reply, {:ok, state.token_gates}, state}
  end

  @impl true
  def handle_call(:list_roles, _from, state) do
    roles = Enum.map(state.roles, fn {name, perms} -> {name, MapSet.to_list(perms)} end)
    {:reply, {:ok, roles}, state}
  end

  defp normalize(address) when is_binary(address), do: String.downcase(address)
  defp normalize(other), do: other
end
