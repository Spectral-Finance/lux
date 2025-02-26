defmodule Lux.Company.DSLTest do
  use UnitCase, async: true

  describe "company definition" do
    defmodule TestCompany do
      @moduledoc false
      use Lux.Company

      company do
        name("Test Company")
        mission("To test all the things")

        has_ceo "Test CEO" do
          agent(TestAgent)
          goal("Lead the testing efforts")
          can("test")
          can("review")
          can("approve")
        end

        members do
          has_role "Test Engineer" do
            agent({"test-123", :test_hub})
            goal("Write and execute tests")
            can("write_tests")
            can("run_tests")
          end

          has_role "QA Analyst" do
            agent(TestQA)
            goal("Ensure quality")
            can("analyze")
            can("report")
          end
        end

        objective :run_test_suite do
          description("Run the complete test suite")
          success_criteria("All tests pass with >90% coverage")

          input(%{
            required: ["test_input"],
            properties: %{
              "test_input" => %{type: "string"}
            }
          })

          steps([
            "Prepare test environment",
            "Run unit tests",
            "Run integration tests",
            "Generate coverage report"
          ])
        end
      end
    end

    test "defines a company with proper attributes" do
      company = TestCompany.view()

      assert is_binary(company.id)
      assert company.name == "Test Company"
      assert company.mission == "To test all the things"
      assert company.module == TestCompany
    end

    test "defines CEO role correctly" do
      company = TestCompany.view()
      ceo = company.ceo

      assert ceo.type == :ceo
      assert is_binary(ceo.id)
      assert ceo.name == "Test CEO"
      assert ceo.goal == "Lead the testing efforts"
      assert ceo.agent == TestAgent
      assert ceo.capabilities == ["approve", "review", "test"]
    end

    test "defines member roles correctly" do
      company = TestCompany.view()
      [qa, engineer] = Enum.sort_by(company.roles, & &1.name)

      # Test Engineer assertions
      assert engineer.type == :member
      assert is_binary(engineer.id)
      assert engineer.name == "Test Engineer"
      assert engineer.goal == "Write and execute tests"
      assert engineer.agent == {"test-123", :test_hub}
      assert engineer.hub == :test_hub
      assert engineer.capabilities == ["run_tests", "write_tests"]

      # QA Analyst assertions
      assert qa.type == :member
      assert is_binary(qa.id)
      assert qa.name == "QA Analyst"
      assert qa.goal == "Ensure quality"
      assert qa.agent == TestQA
      assert is_nil(qa.hub)
      assert qa.capabilities == ["report", "analyze"]
    end

    test "defines objectives correctly" do
      company = TestCompany.view()
      [objective] = company.objectives

      assert objective.name == :run_test_suite
      assert is_binary(objective.id)
      assert objective.description == "Run the complete test suite"
      assert objective.success_criteria == "All tests pass with >90% coverage"

      assert objective.steps == [
               "Prepare test environment",
               "Run unit tests",
               "Run integration tests",
               "Generate coverage report"
             ]
    end

    test "generates required module functions" do
      # Test that all required functions are defined
      assert function_exported?(TestCompany, :view, 0)
      assert function_exported?(TestCompany, :__company__, 0)

      # Test that the functions return the same data
      assert TestCompany.view() == TestCompany.__company__()
    end
  end

  describe "company validation" do
    test "company requires a name" do
      assert_raise CompileError, fn ->
        defmodule InvalidCompany1 do
          @moduledoc false
          use Lux.Company

          company do
            mission("Missing name")
          end
        end
      end
    end

    test "company requires a mission" do
      assert_raise CompileError, fn ->
        defmodule InvalidCompany2 do
          @moduledoc false
          use Lux.Company

          company do
            name("Missing mission")
          end
        end
      end
    end
  end

  describe "role validation" do
    test "roles require a name and agent" do
      assert_raise CompileError, fn ->
        defmodule InvalidCompany3 do
          @moduledoc false
          use Lux.Company

          company do
            name("Invalid Roles")
            mission("Testing invalid roles")

            has_ceo "CEO" do
              # Missing agent
              goal("Lead")
            end
          end
        end
      end
    end
  end

  describe "objective validation" do
    test "objectives require description and success criteria" do
      assert_raise CompileError, fn ->
        defmodule InvalidCompany4 do
          @moduledoc false
          use Lux.Company

          company do
            name("Invalid Objectives")
            mission("Testing invalid objectives")

            has_ceo "CEO" do
              agent(TestAgent)
              goal("Lead")
            end

            objective :invalid do
              # Missing description and success_criteria
              steps(["Step 1"])
            end
          end
        end
      end
    end
  end
end
