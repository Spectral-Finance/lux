defmodule Test.Support.Companies.CapabilityTeam do
  @moduledoc """
  Test company configuration with roles having specific capabilities.
  """

  use Lux.Company

  company do
    name("Capability Test Team")
    mission("Test capability-based task distribution")

    has_ceo "Project Director" do
      agent(Test.Support.Agents.ProjectDirector)
      goal("Oversee project execution and team coordination")
      can("management")
      can("planning")
      can("delegation")
    end

    members do
      has_role "Researcher" do
        agent(Test.Support.Agents.Researcher)
        goal("Conduct research and data collection")
        can("research")
        can("data_collection")
        can("analysis")
      end

      has_role "Analyst" do
        agent(Test.Support.Agents.Analyst)
        goal("Analyze data and create reports")
        can("analysis")
        can("data_processing")
        can("reporting")
      end

      has_role "Writer" do
        agent(Test.Support.Agents.Writer)
        goal("Create and edit content")
        can("writing")
        can("editing")
        can("content_creation")
      end
    end

    objective :multi_capability_task do
      description("A project requiring multiple capabilities")

      success_criteria(
        "All required capabilities are matched and tasks are distributed optimally"
      )

      input(%{
        required: ["title", "required_capabilities"],
        properties: %{
          "title" => %{type: "string"},
          "required_capabilities" => %{type: "array"}
        }
      })

      steps("""
      Research Phase: Gather and analyze data
      Analysis Phase: Process and analyze findings
      Documentation Phase: Create final documentation
      """)
    end
  end
end
