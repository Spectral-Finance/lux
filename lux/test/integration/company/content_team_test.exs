defmodule Lux.Integration.Company.ContentTeamTest do
  @moduledoc """
  This module contains integration tests that go through company creation and execution.
  """
  use IntegrationCase, async: true

  alias Lux.Company.Hub.Local
  alias Test.Support.Companies.ContentTeam

  @moduletag :integration

  describe "content creation workflow" do
    setup do
      # Start a local hub for the company
      hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
      table_name = :"table_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Local, name: hub_name, table_name: table_name})

      # Get the company configuration
      company_config = ContentTeam.view()

      # Start the company
      {:ok, company_pid} =
        Lux.Company.start_link(ContentTeam, %{
          name: company_config.name,
          hub: hub_name
        })

      # Register the company with the hub
      {:ok, company_id} = Local.register_company(company_config, hub_name)

      %{company_pid: company_pid, hub: hub_name, company_id: company_id}
    end

    test "successfully creates a blog post", %{company_pid: pid, hub: hub, company_id: company_id} do
      # 1. Start a blog post objective
      {:ok, objective} =
        Lux.Company.run_objective(pid, :create_blog_post, %{
          "topic" => "Testing in Elixir",
          "target_audience" => "developers",
          "tone" => "technical"
        })

      objective_id = objective.payload["id"]

      # 2. Wait for initial objective setup
      # :timer.sleep(500)
      {:ok, initial_status} = Lux.Company.get_objective_status(pid, objective_id)
      assert initial_status == :in_progress

      # 3. Verify company structure
      {:ok, company} = Local.get_company(company_id, hub)
      assert company.name == "Content Creation Team"
      # Two members (researcher and writer)
      assert length(company.roles) == 2
      # Has a CEO (editor)
      assert company.ceo != nil

      # 4. Monitor the research phase
      researcher = Enum.find(company.roles, &(&1.name == "Research Specialist"))
      assert researcher != nil

      # 5. Wait for research completion
      :timer.sleep(1000)
      {:ok, research_objective} = Lux.Company.get_objective(pid, objective_id)
      assert research_objective.progress > 0

      # 6. Monitor the writing phase
      writer = Enum.find(company.roles, &(&1.name == "Content Writer"))
      assert writer != nil

      # 7. Wait for writing completion
      :timer.sleep(1000)
      {:ok, writing_objective} = Lux.Company.get_objective(pid, objective_id)
      assert writing_objective.progress > research_objective.progress

      # 8. Monitor the editing phase
      assert company.ceo.name == "Content Director"

      # 9. Wait for final completion
      :timer.sleep(1000)
      {:ok, final_status} = Lux.Company.get_objective_status(pid, objective_id)
      {:ok, final_objective} = Lux.Company.get_objective(pid, objective_id)

      # 10. Verify the final result
      assert final_status in [:completed, :in_progress]
      assert final_objective.progress >= writing_objective.progress

      # 11. Check the output artifacts
      {:ok, artifacts} = Lux.Company.get_objective_artifacts(pid, objective_id)
      assert length(artifacts) > 0

      # Verify each artifact has the expected structure
      Enum.each(artifacts, fn artifact ->
        assert Map.has_key?(artifact, :type)
        assert Map.has_key?(artifact, :content)
      end)
    end

    test "handles invalid objective inputs", %{company_pid: pid} do
      # Test with missing required fields
      assert {
               :ok,
               %{
                 payload: %{
                   "result" => %{"error" => "{:error, :invalid_input}", "success" => false},
                   "status" => "failed",
                   "type" => "failure"
                 },
                 schema_id: TaskSignal
               }
             } =
               Lux.Company.run_objective(pid, :create_blog_post, %{
                 # Missing target_audience and tone
                 "topic" => "Testing"
               })

      # Test with invalid objective name
      assert {
               :ok,
               %{
                 payload: %{
                   "result" => %{"error" => "{:error, :objective_not_found}", "success" => false},
                   "status" => "failed",
                   "type" => "failure"
                 },
                 schema_id: TaskSignal
               }
             } =
               Lux.Company.run_objective(pid, :invalid_objective, %{
                 "topic" => "Testing",
                 "target_audience" => "developers",
                 "tone" => "technical"
               })
    end

    test "handles agent failures gracefully", %{company_pid: pid} do
      # Start an objective with a topic known to trigger failure
      {:ok, objective_id} =
        Lux.Company.run_objective(pid, :create_blog_post, %{
          # Special topic that triggers failure
          "topic" => "FAIL_TEST",
          "target_audience" => "developers",
          "tone" => "technical"
        })

      # Wait for failure handling
      :timer.sleep(2000)
      {:ok, status} = Lux.Company.get_objective_status(pid, objective_id)

      # Verify failure was handled
      assert status in [:failed, :in_progress]

      if status == :failed do
        assert status.error != nil
        # Should have error message
        assert is_binary(status.error)
      end
    end

    test "company maintains state across multiple objectives", %{company_pid: pid} do
      # Run first objective
      {:ok, objective1_id} =
        Lux.Company.run_objective(pid, :create_blog_post, %{
          "topic" => "First Post",
          "target_audience" => "developers",
          "tone" => "technical"
        })

      # Start second objective while first is running
      {:ok, objective2_id} =
        Lux.Company.run_objective(pid, :create_blog_post, %{
          "topic" => "Second Post",
          "target_audience" => "developers",
          "tone" => "technical"
        })

      # Wait for some progress
      :timer.sleep(5000)

      # Check both objectives
      {:ok, objective1_status} = Lux.Company.get_objective_status(pid, objective1_id)
      {:ok, objective2_status} = Lux.Company.get_objective_status(pid, objective2_id)

      # Verify both objectives are being processed
      assert objective1_status in [:in_progress, :completed]
      assert objective2_status in [:in_progress, :completed]

      # Verify company can handle multiple objectives
      {:ok, active_objectives} = Lux.Company.list_objectives(pid)
      assert length(active_objectives) >= 1
    end
  end
end
