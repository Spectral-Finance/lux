defmodule Lux.Integration.AgentCollaborationTest do
  # Now we can safely run async
  use IntegrationCase, async: true

  alias Lux.Agent
  alias Lux.AgentHub

  # Example agents for testing collaboration
  defmodule ResearchAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Research Assistant",
      description: "An AI research assistant specialized in finding and analyzing information",
      goal: "Help find and analyze relevant information",
      capabilities: [:research, :analysis],
      llm_config: %{
        model: "gpt-3.5-turbo",
        temperature: 0.7,
        messages: [
          %{
            role: "system",
            content: """
            You are a Research Assistant focused on finding and analyzing information.
            When you receive questions, analyze them carefully and provide detailed responses.
            """
          }
        ]
      }
  end

  defmodule WriterAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Content Writer",
      description: "An AI writer that can create engaging content",
      goal: "Create well-written content based on research",
      capabilities: [:writing, :editing],
      llm_config: %{
        model: "gpt-3.5-turbo",
        temperature: 0.7,
        messages: [
          %{
            role: "system",
            content: """
            You are a Content Writer focused on creating engaging content.
            When you receive research information, transform it into well-written content.
            """
          }
        ]
      }
  end

  describe "multi-agent collaboration" do
    setup do
      # Start a new hub for each test
      hub_name = :"test_hub_#{:erlang.unique_integer([:positive])}"
      {:ok, _hub} = start_supervised({AgentHub, name: hub_name})

      llm_config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest]
      }

      # Start both agents with unique names
      researcher_name = :"researcher_#{:erlang.unique_integer([:positive])}"
      writer_name = :"writer_#{:erlang.unique_integer([:positive])}"

      {:ok, researcher_pid} =
        start_supervised({ResearchAgent, name: researcher_name, llm_config: llm_config})

      {:ok, writer_pid} =
        start_supervised({WriterAgent, name: writer_name, llm_config: llm_config})

      researcher = :sys.get_state(researcher_pid)
      writer = :sys.get_state(writer_pid)

      # Register agents with their capabilities
      :ok = AgentHub.register(hub_name, researcher, researcher_pid, [:research, :analysis])
      :ok = AgentHub.register(hub_name, writer, writer_pid, [:writing, :editing])

      {:ok,
       hub: hub_name,
       researcher: researcher,
       writer: writer,
       researcher_pid: researcher_pid,
       writer_pid: writer_pid}
    end

    test "agents can discover each other by capability", %{
      hub: hub,
      researcher: researcher,
      writer: writer
    } do
      # Find agents by capability
      research_agents = AgentHub.find_by_capability(hub, :research)
      writing_agents = AgentHub.find_by_capability(hub, :writing)

      assert length(research_agents) == 1
      assert length(writing_agents) == 1

      [research_info] = research_agents
      [writer_info] = writing_agents

      assert research_info.agent.id == researcher.id
      assert writer_info.agent.id == writer.id
    end

    test "agents can collaborate on a task", %{
      hub: hub,
      researcher_pid: researcher_pid,
      writer_pid: writer_pid,
      researcher: researcher
    } do
      # Simulate a research and writing task
      {:ok, research_response} =
        ResearchAgent.send_message(researcher_pid, "Research the benefits of exercise",
          timeout: 30_000
        )

      # Update status to show the researcher is working
      :ok = AgentHub.update_status(hub, researcher.id, :busy)

      assert is_binary(research_response)
      assert String.length(research_response) > 0

      # Send research results to the writer
      {:ok, written_content} =
        WriterAgent.send_message(
          writer_pid,
          "Create an engaging blog post based on this research: #{research_response}",
          timeout: 30_000
        )

      # Update status when the task is complete
      :ok = AgentHub.update_status(hub, researcher.id, :available)

      assert is_binary(written_content)
      assert String.length(written_content) > 0
    end

    test "agents handle status updates correctly", %{hub: hub, researcher: researcher} do
      # Update status
      :ok = AgentHub.update_status(hub, researcher.id, :busy)
      {:ok, info} = AgentHub.get_agent_info(hub, researcher.id)
      assert info.status == :busy

      :ok = AgentHub.update_status(hub, researcher.id, :available)
      {:ok, info} = AgentHub.get_agent_info(hub, researcher.id)
      assert info.status == :available
    end

    test "hub tracks agent availability", %{
      hub: hub,
      researcher_pid: researcher_pid,
      researcher: researcher
    } do
      # Initially available
      {:ok, info} = AgentHub.get_agent_info(hub, researcher.id)
      assert info.status == :available

      # Monitor the agent process
      ref = Process.monitor(researcher_pid)

      # Stop the supervised process
      stop_supervised(ResearchAgent)

      # Wait for the DOWN message
      assert_receive {:DOWN, ^ref, :process, ^researcher_pid, _}, 1000

      # Wait for the hub to process the status change
      assert eventually(fn ->
               case AgentHub.get_agent_info(hub, researcher.id) do
                 {:ok, info} -> info.status == :offline
                 _ -> false
               end
             end)
    end

    # Helper function to retry assertions
    defp eventually(func, retries \\ 10, delay \\ 50) do
      if func.() do
        true
      else
        if retries > 0 do
          Process.sleep(delay)
          eventually(func, retries - 1, delay)
        else
          false
        end
      end
    end
  end
end
