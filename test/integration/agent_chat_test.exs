defmodule Lux.Integration.AgentChatTest do
  use IntegrationCase, async: true

  alias Lux.Memory.SimpleMemory

  # Fixed seed for deterministic responses in tests
  @seed 42

  defmodule TestPrism do
    @moduledoc """
    A test prism that can be used to test the agent.
    """
    use Lux.Prism,
      name: "#{TestPrism}",
      id: TestPrism,
      description: "A test prism that can be used to test the agent.",
      input_schema: %{
        type: "object",
        properties: %{message: %{type: "string"}},
        required: [:message]
      }

    def handler(%{"message" => message}, _opts) do
      {:ok, %{message: message <> " from TestPrism"}}
    end
  end

  defmodule ChatAgent do
    @moduledoc """
    An example agent that can engage in chat conversations.
    """
    use Lux.Agent

    @impl true
    def new(opts) do
      llm_config = %{
        api_key: opts[:api_key] || Application.get_env(:lux, :api_keys)[:integration_openai],
        model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:cheapest],
        receive_timeout: opts[:receive_timeout] || 30_000,
        messages: [
          %{
            role: "system",
            content: """
            You are #{opts[:name] || "Chat Assistant"}. #{opts[:description] || "A helpful chat assistant that can engage in conversations"}
            Your goal is: #{opts[:goal] || "Help users by engaging in meaningful conversations and providing assistance"}
            Respond to the user's message in a helpful and engaging way.
            """
          }
        ]
      }

      Lux.Agent.new(%{
        name: opts[:name] || "Chat Assistant",
        description:
          opts[:description] || "A helpful chat assistant that can engage in conversations",
        goal:
          opts[:goal] ||
            "Help users by engaging in meaningful conversations and providing assistance. You keep your responses short and concise.",
        module: __MODULE__,
        prisms: [
          TestPrism
        ],
        llm_config: llm_config,
        memory_config: %{
          backend: SimpleMemory,
          name: :test_memory
        }
      })
    end
  end

  describe "agent chat" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.0,
        max_tokens: 50,
        seed: @seed
      }

      # Create and start a new chat agent
      {:ok, pid} =
        ChatAgent.start_link(%{
          name: "Research Assistant",
          description:
            "An AI research assistant specialized in scientific literature and analysis",
          goal: "Help researchers find, understand, and analyze scientific papers",
          llm_config: config
        })

      {:ok, pid: pid}
    end

    test "can chat with the agent", %{pid: pid} do
      {:ok, response} = ChatAgent.send_message(pid, "Can you define petricor?")

      assert is_binary(response)
      assert String.length(response) > 0
      # The response should be relevant to petrology
      assert response =~ ~r/minerals|smell|rain/i
    end

    test "maintains consistent persona across chats", %{pid: pid} do
      # First chat to establish role
      {:ok, response1} = ChatAgent.send_message(pid, "What kind of assistant are you?")
      assert is_binary(response1)
      assert response1 =~ ~r/research|scientific|papers|literature/i

      # Second chat to verify consistent persona
      {:ok, response2} = ChatAgent.send_message(pid, "Can you help with academic papers?")
      assert is_binary(response2)
      assert response2 =~ ~r/research|papers|analysis|literature|scientific/i
    end

    test "can use prisms", %{pid: pid} do
      {:ok, %Lux.Signal{payload: %{content: nil, tool_calls_results: [%{message: message}]}}} =
        ChatAgent.send_message(pid, "Could you use the TestPrism for testing the agent?")

      assert is_binary(message)
      assert message =~ "from TestPrism"
    end
  end

  describe "chat with memory" do
    setup do
      config = %{
        api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
        model: Application.get_env(:lux, :open_ai_models)[:cheapest],
        temperature: 0.0,
        max_tokens: 50,
        seed: @seed
      }

      # Create and start a new chat agent with memory
      {:ok, pid} =
        ChatAgent.start_link(%{
          name: "Memory-Enabled Assistant",
          description: "An assistant that remembers past interactions",
          goal: "Help users while maintaining context of conversations",
          llm_config: config,
          memory_config: %{
            backend: SimpleMemory,
            name: :test_memory
          }
        })

      {:ok, pid: pid}
    end

    test "stores interactions in memory when enabled", %{pid: pid} do
      # Send a message with memory enabled
      {:ok, response1} = ChatAgent.send_message(pid, "What's your name?", use_memory: true)
      assert is_binary(response1)

      # Verify the interaction was stored
      agent = :sys.get_state(pid)
      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 2)
      assert length(recent) == 2

      [assistant_msg, user_msg] = recent
      assert user_msg.content == "What's your name?"
      assert user_msg.metadata.role == :user
      assert assistant_msg.metadata.role == :assistant
    end

    test "includes memory context in subsequent chats", %{pid: pid} do
      # First interaction
      {:ok, _} = ChatAgent.send_message(pid, "My name is John", use_memory: true)

      # Second interaction should reference the previous context
      {:ok, response} =
        ChatAgent.send_message(pid, "What's my name? (do not use any tools...)", use_memory: true)

      assert response =~ ~r/john/i

      # Verify all interactions were stored
      agent = :sys.get_state(pid)
      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 4)
      assert length(recent) == 4
    end

    test "respects max_memory_context limit", %{pid: pid} do
      # Send multiple messages
      messages = [
        "Message 1 - use no tools",
        "Message 2 - use no tools",
        "Message 3 - use no tools",
        "Message 4 - use no tools",
        "Message 5 - use no tools"
      ]

      # Process messages sequentially and ensure each one completes
      Enum.each(messages, fn msg ->
        {:ok, _response} = ChatAgent.send_message(pid, msg, use_memory: true)
        # Get state to ensure message was processed
        agent = :sys.get_state(pid)
        {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 2)
        # Verify each message + response pair
        assert length(recent) == 2
      end)

      # Send a message with limited context
      {:ok, _} =
        ChatAgent.send_message(pid, "Final message",
          use_memory: true,
          max_memory_context: 3
        )

      # Verify all messages were stored (5 initial + 1 final = 6 messages, each with a response)
      agent = :sys.get_state(pid)
      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 12)
      # 6 messages * 2 (user + assistant)
      assert length(recent) == 12

      # Verify the chronological order
      messages_in_memory = Enum.map(recent, & &1.content)
      assert Enum.any?(messages_in_memory, &(&1 =~ "Message 1"))
      assert Enum.any?(messages_in_memory, &(&1 =~ "Final message"))
    end

    test "memory is disabled by default", %{pid: pid} do
      # Send a message without enabling memory
      {:ok, response} = ChatAgent.send_message(pid, "Hello")
      assert is_binary(response)

      # Verify no interactions were stored
      agent = :sys.get_state(pid)

      {:ok, recent} = SimpleMemory.recent(agent.memory_pid, 2)
      assert recent == []
    end
  end
end
