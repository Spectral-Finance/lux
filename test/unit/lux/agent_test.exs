defmodule Lux.AgentTest do
  use UnitCase, async: true

  alias Lux.Agent
  alias Lux.Memory.SimpleMemory

  # Test modules
  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      description: "A test prism"

    def handler(_params, _context), do: {:ok, %{result: "test"}}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      description: "A test beam"

    def steps do
      sequence do
        step(:test, TestPrism, %{})
      end
    end
  end

  defmodule SimpleAgent do
    @moduledoc false
    use Lux.Agent,
      name: "Simple Agent",
      description: "A simple agent that keeps things simple.",
      goal: "You have one simple goal. Not making things too complicated.",
      prisms: [TestPrism],
      beams: [TestBeam]
  end

  defmodule MemoryAgent do
    @moduledoc false
    use Lux.Agent

    def new(_opts \\ %{}) do
      Agent.new(%{
        name: "Memory Agent",
        description: "An agent with memory capabilities",
        goal: "Remember and use past interactions",
        memory_config: %{
          backend: SimpleMemory,
          name: :test_memory
        }
      })
    end

    # We override the chat functions to store the messages in memory here and do not actually call any LLM...
    @impl true
    def chat(agent, message, _opts) do
      response = "Response to: " <> message

      with {:ok, _} <-
             SimpleMemory.add(
               agent.memory_pid,
               message,
               :interaction,
               %{role: :user}
             ) do
        {:ok, _} =
          SimpleMemory.add(
            agent.memory_pid,
            response,
            :interaction,
            %{role: :assistant}
          )

        {:ok, response}
      end
    end
  end

  describe "new/1" do
    test "creates a new agent with default values" do
      agent = Agent.new(%{})
      assert agent.id != nil
      assert agent.name == "Anonymous Agent"
      assert agent.description == ""
      assert agent.goal == ""
      assert agent.prisms == []
      assert agent.beams == []
      assert agent.lenses == []
      assert agent.memory_config == nil
      assert agent.memory_pid == nil
    end

    test "creates a new agent with custom values" do
      attrs = %{
        name: "Test Agent",
        description: "A test agent",
        goal: "Test goal",
        prisms: [TestPrism],
        beams: [TestBeam],
        llm_config: %{model: "gpt-3.5-turbo"},
        memory_config: %{
          backend: SimpleMemory,
          name: :test_memory
        }
      }

      agent = Agent.new(attrs)
      assert agent.name == "Test Agent"
      assert agent.description == "A test agent"
      assert agent.goal == "Test goal"
      assert agent.prisms == [TestPrism]
      assert agent.beams == [TestBeam]
      assert agent.llm_config.model == "gpt-3.5-turbo"
      assert agent.memory_config.backend == SimpleMemory
      assert agent.memory_config.name == :test_memory
    end

    test "can also be called from modules using the __using__ macro" do
      assert %Agent{
               name: "Simple Agent",
               description: "A simple agent that keeps things simple.",
               goal: "You have one simple goal. Not making things too complicated.",
               prisms: [TestPrism],
               beams: [TestBeam],
               llm_config: %{
                 model: "gpt-123",
                 temperature: 0.7,
                 max_tokens: 1000
               }
             } =
               SimpleAgent.new(%{
                 name: "Simple Agent",
                 description: "A simple agent that keeps things simple.",
                 goal: "You have one simple goal. Not making things too complicated.",
                 prisms: [TestPrism],
                 beams: [TestBeam],
                 llm_config: %{
                   model: "gpt-123",
                   temperature: 0.7,
                   max_tokens: 1000
                 }
               })
    end
  end

  describe "memory operations" do
    test "initializes memory on start" do
      {:ok, pid} = MemoryAgent.start_link()
      agent = :sys.get_state(pid)
      assert is_pid(agent.memory_pid)
    end

    test "stores and retrieves interactions" do
      {:ok, pid} = MemoryAgent.start_link()

      # Send a message
      {:ok, response} = MemoryAgent.send_message(pid, "Hello")
      assert response == "Response to: Hello"

      # Check stored messages
      agent = :sys.get_state(pid)
      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 2)

      assert length(recent) == 2
      [assistant_msg, user_msg] = recent

      assert assistant_msg.content == "Response to: Hello"
      assert assistant_msg.type == :interaction
      assert assistant_msg.metadata.role == :assistant

      assert user_msg.content == "Hello"
      assert user_msg.type == :interaction
      assert user_msg.metadata.role == :user
    end
  end

  describe "can be started with a unique name" do
    test "can be started with a unique name", %{test: test_name} do
      name1 = String.replace("Test_Agent_1_#{test_name}", " ", "_")
      name2 = String.replace("Test_Agent_2_#{test_name}", " ", "_")

      # Start two agents with different names
      pid1 = start_supervised!({SimpleAgent, %{name: name1}})
      pid2 = start_supervised!({SimpleAgent, %{name: name2}})

      # Verify they are different processes
      assert pid1 != pid2

      # Get their states to verify they have the correct names
      agent1 = :sys.get_state(pid1)
      agent2 = :sys.get_state(pid2)

      assert agent1.name == name1
      assert agent2.name == name2

      assert_raise RuntimeError, fn ->
        start_supervised!({SimpleAgent, %{name: name1}})
      end
    end
  end
end
