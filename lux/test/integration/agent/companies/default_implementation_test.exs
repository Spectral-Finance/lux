defmodule Lux.Integration.Agent.Companies.DefaultImplementationTest do
  use IntegrationCase, async: true

  alias Lux.Agent.Companies.SignalHandler.DefaultImplementation
  alias Lux.Config
  alias Lux.Schemas.Companies.TaskSignal
  alias Lux.Signal
  alias Test.Support.Companies.ContentTeam.SearchPrism
  alias Test.Support.Companies.ContentTeam.SummarizeLens
  alias Test.Support.Companies.ContentTeam.TestAgent

  describe "task execution with real LLM" do
    setup do
      # Initialize the test agent with tools
      {:ok, agent} =
        TestAgent.start_link(
          tools: [
            SearchPrism,
            SummarizeLens
          ]
        )

      # Create proper context with the agent
      context = %{
        agent: agent,
        beams: [],
        lenses: [SummarizeLens],
        prisms: [SearchPrism],
        template_opts: %{
          llm_opts: %{
            provider: :open_ai,
            model: Config.runtime(:open_ai_models, [:default]),
            temperature: 0.7,
            max_tokens: 500,
            api_key: Config.runtime(:api_keys, [:integration_openai])
          }
        }
      }

      text = """
      The quick brown fox jumps over the lazy dog.
      This pangram contains every letter of the English alphabet.
      It is often used for testing fonts and keyboards.
      """

      signal = %Signal{
        id: "test-1",
        schema_id: TaskSignal,
        payload: %{
          "type" => "assignment",
          "task_id" => "task-1",
          "objective_id" => "obj-1",
          "title" => "Analyze Text",
          "description" => "Search for 'fox' in the text and provide a summary.",
          "context" => %{
            "text" => text
          }
        },
        sender: "sender-1"
      }

      %{context: context, signal: signal, agent: agent}
    end

    test "executes task with real tools", %{context: context, signal: signal} do
      assert {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "completion"
      assert response.payload["status"] == "completed"
      assert response.payload["result"]["success"] == true

      # Verify the result contains both search and summary
      result = Jason.decode!(response.payload["result"]["output"])

      assert is_map(result)
      assert Map.has_key?(result, "search")
      assert Map.has_key?(result, "summary")
      assert result["search"]["found"] == true
      # Fix the expected values to match actual tool implementations
      assert result["search"]["matches"] == [
               """
               The quick brown fox jumps over the lazy dog.
               This pangram contains every letter of the English alphabet.
               It is often used for testing fonts and keyboards.
               """
             ]

      assert String.starts_with?(result["summary"], "The quick brown fox")
    end

    @tag :integration
    test "handles task with unknown requirements gracefully", %{context: context, signal: signal} do
      signal = put_in(signal.payload["description"], "Do something impossible")

      assert {:ok, response} = DefaultImplementation.handle_task_assignment(signal, context)
      assert response.schema_id == TaskSignal
      assert response.payload["type"] == "failure"
      assert response.payload["status"] == "failed"
      assert response.payload["result"]["success"] == false
    end

    # Clean up after tests
    setup %{agent: agent} do
      on_exit(fn ->
        if Process.alive?(agent) do
          GenServer.stop(agent)
        end
      end)

      :ok
    end
  end
end
