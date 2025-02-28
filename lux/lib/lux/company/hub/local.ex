defmodule Lux.Company.Hub.Local do
  @moduledoc """
  Local implementation of the company hub.
  Manages company state and agent communication within a single BEAM node.
  """

  @behaviour Lux.Company.Hub

  use GenServer

  alias Lux.Company
  alias Lux.Company.Hub

  @doc """
  Starts the local hub.
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    table_name = Keyword.fetch!(opts, :table_name)
    GenServer.start_link(__MODULE__, table_name, name: name)
  end

  @impl Hub
  def register_company(company, hub) when is_atom(company) do
    # Handle module-based company registration
    company_struct = %Company{
      id: Lux.UUID.generate(),
      name: company.name(),
      mission: company.mission(),
      module: company,
      ceo: company.ceo(),
      roles: company.roles(),
      objectives: company.objectives()
    }

    register_company(company_struct, hub)
  end

  @impl Hub
  def register_company(%Company{} = company_struct, hub) do
    GenServer.call(hub, {:register_company, company_struct})
  end

  @impl Hub
  def get_company(id, hub) do
    GenServer.call(hub, {:get_company, id})
  end

  @impl Hub
  def list_companies(hub) do
    GenServer.call(hub, :list_companies)
  end

  @impl Hub
  def search_companies(query, hub, opts \\ []) do
    GenServer.call(hub, {:search_companies, query, opts})
  end

  @impl Hub
  def deregister_company(id, hub) do
    GenServer.call(hub, {:deregister_company, id})
  end

  @doc """
  Gets an agent by ID from the company.
  """
  @spec get_agent(String.t(), hub :: GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_agent(agent_id, hub) do
    GenServer.call(hub, {:get_agent, agent_id})
  end

  # Server Callbacks

  @impl true
  def init(table_name) do
    table = :ets.new(table_name, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:register_company, company}, _from, state) do
    true = :ets.insert(state.table, {company.id, company})
    {:reply, {:ok, company.id}, state}
  end

  def handle_call({:get_company, id}, _from, state) do
    case :ets.lookup(state.table, id) do
      [{^id, company}] -> {:reply, {:ok, company}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list_companies, _from, state) do
    companies = state.table |> :ets.tab2list() |> Enum.map(fn {_id, company} -> company end)
    {:reply, {:ok, companies}, state}
  end

  def handle_call({:search_companies, query, _opts}, _from, state) do
    companies =
      state.table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, company} -> company end)
      |> Enum.filter(fn company ->
        String.contains?(String.downcase(company.name), String.downcase(query))
      end)

    {:reply, {:ok, companies}, state}
  end

  def handle_call({:deregister_company, id}, _from, state) do
    :ets.delete(state.table, id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_agent, agent_id}, _from, state) do
    # Find company that has this agent (either as CEO or role)
    result =
      state.table
      |> :ets.tab2list()
      |> Enum.find_value(
        {:error, :not_found},
        fn {_id, company} ->
          if company.ceo && company.ceo.id == agent_id do
            {:ok, company.ceo}
          else
            # credo:disable-for-next-line
            case Enum.find(company.roles || [], &(&1.id == agent_id)) do
              nil -> false
              role -> {:ok, role}
            end
          end
        end
      )

    {:reply, result, state}
  end
end
