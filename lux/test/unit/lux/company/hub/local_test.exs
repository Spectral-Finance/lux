defmodule Lux.Company.Hub.LocalTest do
  use Lux.CompanyCase

  alias Lux.Company.Hub.Local

  require Logger

  # Define a proper test company using the DSL
  defmodule TestCompany do
    @moduledoc false
    use Lux.Company

    company do
      name("Test Company")
      mission("Testing company functionality")

      has_ceo "Test CEO" do
        agent(Test.Support.Agents.TestCEO)
        goal("Lead and manage test company operations")
        can("manage_company")
        can("assign_tasks")
      end

      members do
        has_role "Test Member" do
          agent(Test.Support.Agents.TestMember)
          goal("Execute test tasks effectively")
          can("execute_tasks")
        end
      end
    end

    def name, do: "Test Company"
    def mission, do: "Testing company functionality"

    def ceo,
      do: %{
        id: Lux.UUID.generate(),
        name: "Test CEO",
        capabilities: ["manage_company", "assign_tasks"]
      }

    def roles,
      do: [%{id: Lux.UUID.generate(), name: "Test Member", capabilities: ["execute_tasks"]}]

    def objectives, do: []
  end

  describe "local hub implementation" do
    test "registers and retrieves a company", %{hub: hub} do
      company = create_test_company("Test Company")
      assert {:ok, company_id} = Local.register_company(company, hub)
      assert is_binary(company_id)
      assert {:ok, retrieved} = Local.get_company(company_id, hub)
      assert retrieved.name == company.name
    end

    test "lists registered companies", %{hub: hub} do
      company1 = create_test_company("Company 1")
      company2 = create_test_company("Company 2")

      assert {:ok, _id1} = Local.register_company(company1, hub)
      assert {:ok, _id2} = Local.register_company(company2, hub)

      assert {:ok, companies} = Local.list_companies(hub)
      assert length(companies) == 2
      assert Enum.any?(companies, &(&1.id == company1.id))
      assert Enum.any?(companies, &(&1.id == company2.id))
    end

    test "deregisters a company", %{hub: hub} do
      company = create_test_company("Test Company")
      assert {:ok, company_id} = Local.register_company(company, hub)
      assert :ok = Local.deregister_company(company_id, hub)
      assert {:error, :not_found} = Local.get_company(company_id, hub)
    end

    test "handles company module registration", %{hub: hub} do
      assert {:ok, company_id} = Local.register_company(TestCompany, hub)
      assert {:ok, company} = Local.get_company(company_id, hub)
      assert company.name == "Test Company"
      assert company.mission == "Testing company functionality"
      assert company.module == TestCompany
    end

    test "searches companies", %{hub: hub} do
      company1 = create_test_company("Search Company 1")
      company2 = create_test_company("Search Company 2")
      company3 = create_test_company("Other Company")

      assert {:ok, _} = Local.register_company(company1, hub)
      assert {:ok, _} = Local.register_company(company2, hub)
      assert {:ok, _} = Local.register_company(company3, hub)

      assert {:ok, results} = Local.search_companies("Search", hub)
      assert length(results) == 2
      assert Enum.all?(results, &String.contains?(&1.name, "Search"))
    end
  end
end
