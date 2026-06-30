defmodule Lux.CompanyCase do
  @moduledoc """
  This module defines the test case to be used by
  company-related tests.
  """

  use ExUnit.CaseTemplate

  alias Lux.Company
  alias Lux.Company.Hub.Local

  using do
    quote do
      import Lux.CompanyCase

      alias Lux.Company
      alias Lux.Company.Hub
      alias Lux.Company.Hub.Local

      @moduletag :unit
      # Import helpers

      # Alias common test modules
    end
  end

  setup do
    # Start a local company hub for each test
    hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
    table_name = :"table_#{:erlang.unique_integer([:positive])}"

    start_supervised!({Local, name: hub_name, table_name: table_name})

    # Return the hub name so tests can use it
    {:ok, hub: hub_name}
  end

  @doc """
  Creates a test company struct for testing.
  """
  def create_test_company(attrs \\ %{})

  def create_test_company(name) when is_binary(name) do
    create_test_company(%{name: name})
  end

  def create_test_company(attrs) when is_map(attrs) do
    base = %Company{
      id: Lux.UUID.generate(),
      name: "Test Company",
      mission: "Test Mission",
      module: Test.Support.Companies.TestCompany,
      ceo: %{
        id: Lux.UUID.generate(),
        name: "Test CEO",
        capabilities: ["manage", "evaluate"]
      },
      roles: [
        %{
          id: Lux.UUID.generate(),
          name: "Test Role",
          capabilities: ["test"]
        }
      ]
    }

    Map.merge(base, attrs)
  end
end
