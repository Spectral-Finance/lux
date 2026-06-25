defmodule Lux.Integration.Company.YouTubePipelineTest do
  @moduledoc """
  Integration tests for the YouTube Content Creation Pipeline.
  Showcases an end-to-end workflow for generating video scripts, visuals, metadata, and testing plans.
  """
  use IntegrationCase, async: true

  alias Lux.Company.Hub.Local
  alias Lux.Companies.YouTubePipeline

  @moduletag :integration

  describe "youtube content creation workflow" do
    setup do
      # Set up deterministic Req stubs for the LLM API calls made by agents
      Req.Test.stub(OpenAI, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json = body |> Jason.decode!()
        schema_name = get_in(json, ["response_format", "json_schema", "name"]) || "unknown"

        content = 
          case schema_name do
            "script_generation" ->
              ~s({"title_ideas":["Deterministic Idea"],"hook":"Deterministic Hook","outline":["Intro"],"full_script":"Deterministic Script","estimated_duration":5,"editing_suggestions":["Cut here"]})
            "visual_optimization" ->
              ~s({"thumbnail_prompts":["Prompt"],"broll_suggestions":["Broll"],"color_palette":["#FFFFFF"],"end_screen_layout":"Layout","card_placements":["Card"]})
            "metadata_optimization" ->
              ~s({"optimized_title":"Optimized","description":"Desc","tags":["tag"],"category_id":"22","playlist_organization":["Playlist"],"multi_language_support":{"es":{"title":"Titulo","description":"Desc"}}})
            "content_testing_plan" ->
              ~s({"variations":[{"title":"Var 1","thumbnail_concept":"Concept 1","hypothesis":"Hypothesis"}],"test_duration_days":7,"success_metrics":["CTR"],"repurposed_content":{"shorts_transcript":"Transcript","twitter_thread":["Thread"]}})
            _ ->
              ~s({"title_ideas":["Deterministic Idea"],"hook":"Deterministic Hook","outline":["Intro"],"full_script":"Deterministic Script","estimated_duration":5,"editing_suggestions":["Cut here"]})
          end

        Req.Test.json(conn, %{
          "id" => "chatcmpl-mock",
          "object" => "chat.completion",
          "created" => 1_677_652_288,
          "model" => "gpt-4o-mini",
          "choices" => [
            %{
              "index" => 0,
              "message" => %{
                "role" => "assistant",
                "content" => content
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 20, "total_tokens" => 30}
        })
      end)

      # Start a local hub for the company
      hub_name = :"hub_#{:erlang.unique_integer([:positive])}"
      table_name = :"table_#{:erlang.unique_integer([:positive])}"
      start_supervised!({Local, name: hub_name, table_name: table_name})

      # Get the company configuration
      company_config = YouTubePipeline.view()

      # Start the company
      {:ok, company_pid} =
        Lux.Company.run(YouTubePipeline, [
          name: company_config.name,
          hub: hub_name
        ])

      # Register the company with the hub
      {:ok, company_id} = Local.register_company(company_config, hub_name)

      %{company_pid: company_pid, hub: hub_name, company_id: company_id}
    end

    defp wait_for_completion(pid, objective_id, retries \\ 15)
    defp wait_for_completion(_pid, _objective_id, 0), do: :timeout
    defp wait_for_completion(pid, objective_id, retries) do
      {:ok, status} = Lux.Company.get_objective_status(pid, objective_id)
      if status in [:completed, :failed] do
        status
      else
        :timer.sleep(1000)
        wait_for_completion(pid, objective_id, retries - 1)
      end
    end

    test "successfully executes end-to-end content creation workflow", %{company_pid: pid, hub: hub, company_id: company_id} do
      # 1. Start a youtube video creation objective
      {:ok, signal} =
        Lux.Company.run_objective(pid, :create_optimized_video, %{
          "topic" => "Elixir for Beginners: Agentic Workflows",
          "target_audience" => %{
            "age_range" => "18-35",
            "interests" => ["programming", "AI", "software engineering"]
          }
        })
      
      # Depending on how the new signal schema works, get the objective_id
      # It could be embedded in the payload
      objective_id = signal.payload["objective_id"] || signal.payload["id"]

      # If objective_id is nil, fallback to trying to get the active objective
      objective_id = if is_nil(objective_id) do
        {:ok, objectives} = Lux.Company.list_objectives(pid)
        if length(objectives) > 0, do: hd(objectives).id, else: nil
      else
        objective_id
      end
      
      assert objective_id != nil

      # 2. Wait for initial objective setup
      {:ok, initial_status} = Lux.Company.get_objective_status(pid, objective_id)
      assert initial_status in [:in_progress, :completed]

      # 3. Verify company structure
      {:ok, company} = Local.get_company(company_id, hub)
      assert company.name == "YouTube Content Creation Pipeline"
      
      # Should have 3 members (Visual Optimizer, Metadata Manager, Content Tester)
      assert length(company.roles) == 3
      
      # Should have a CEO (Content Director)
      assert company.ceo != nil
      assert company.ceo.name == "Content Director"

      # 4. Wait for objective completion and verify state progression
      final_status = wait_for_completion(pid, objective_id)
      assert final_status == :completed
      
      {:ok, objective} = Lux.Company.get_objective(pid, objective_id)
      
      # Ensure progress is being tracked
      assert objective.progress > 0

      # Assert the full content package shape by checking the context
      context_str = Jason.encode!(objective.context)
      assert context_str =~ "Deterministic Script"
      assert context_str =~ "editing_suggestions"
      assert context_str =~ "thumbnail_prompts"
      assert context_str =~ "playlist_organization"
      assert context_str =~ "multi_language_support"
      assert context_str =~ "repurposed_content"
      assert context_str =~ "variations"
    end
    
    test "handles missing required inputs", %{company_pid: pid} do
      # Start objective without required 'target_audience'
      assert {:error, {:missing_required_fields, ["target_audience"]}} =
        Lux.Company.run_objective(pid, :create_optimized_video, %{
          "topic" => "Incomplete request"
        })
    end
  end
end
