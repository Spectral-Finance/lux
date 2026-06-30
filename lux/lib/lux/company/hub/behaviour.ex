defmodule Lux.Company.Hub do
  @moduledoc """
  Defines the behaviour for company hubs.

  Company hubs manage the registration and discovery of companies. They provide:
  - Company registration and lookup
  - Search functionality
  - Basic company lifecycle management
  """

  alias Lux.Company

  @type company_id :: String.t()
  @type company_module :: module()
  @type search_opts :: keyword()

  @doc """
  Registers a company in the hub.
  Accepts either a module implementing the company behavior or a company struct.
  Returns the unique company ID on success.
  """
  @callback register_company(company_module() | Company.t(), hub :: GenServer.server()) ::
              {:ok, company_id()} | {:error, term()}

  @doc """
  Gets a company by its ID.
  """
  @callback get_company(company_id(), hub :: GenServer.server()) ::
              {:ok, Company.t()} | {:error, term()}

  @doc """
  Lists all registered companies.
  """
  @callback list_companies(hub :: GenServer.server()) ::
              {:ok, [Company.t()]} | {:error, term()}

  @doc """
  Searches for companies based on criteria.
  Supports searching by name, mission, or other attributes.
  """
  @callback search_companies(
              query :: String.t(),
              hub :: GenServer.server(),
              opts :: search_opts()
            ) ::
              {:ok, [Company.t()]} | {:error, term()}

  @doc """
  Deregisters a company from the hub.
  """
  @callback deregister_company(company_id(), hub :: GenServer.server()) ::
              :ok | {:error, term()}
end
