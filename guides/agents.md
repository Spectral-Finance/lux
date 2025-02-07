# Agents Guide

Agents are autonomous components in Lux that can interact with LLMs, process signals, and execute workflows. They combine intelligence with execution capabilities, making them perfect for building conversational and agentic applications.

## Overview

An Agent consists of:
- A unique identifier
- Name and description
- Goal or purpose
- LLM configuration
- Memory configuration (optional)
- Optional components (Prisms, Beams, Lenses)
- Signal handling capabilities

## Creating an Agent

Here's a basic example of an Agent:

```elixir
defmodule MyApp.Agents.Assistant do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    llm_config = %{
      api_key: opts[:api_key] || Lux.Config.openai_api_key(),
      model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:default],
      temperature: 0.7,
      messages: [
        %{
          role: "system",
          content: """
          You are #{opts[:name] || "Simple Assistant"}, #{opts[:description] || "a helpful assistant that can engage in conversations"}.
          Your goal is: #{opts[:goal] || "Help users by providing clear and accurate responses"}
          """
        }
      ]
    }

    Lux.Agent.new(%{
      name: opts[:name] || "Simple Assistant",
      description: opts[:description] || "A helpful assistant that can engage in conversations",
      goal: opts[:goal] || "Help users by providing clear and accurate responses",
      module: __MODULE__,
      llm_config: llm_config
    })
  end
end
```

## Agent Configuration

### Memory Configuration
Agents can be configured with memory to maintain state and recall previous interactions:

```elixir
defmodule MyApp.Agents.MemoryAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Memory-Enabled Assistant",
      description: "An assistant that remembers past interactions",
      goal: "Help users while maintaining context of conversations",
      memory_config: %{
        backend: Lux.Memory.SimpleMemory,
        name: :memory_agent_store
      },
      llm_config: %{
        api_key: Application.get_env(:lux, :api_keys)[:openai],
        model: Application.get_env(:lux, :open_ai_models)[:smartest],
        temperature: 0.7
      }
    })
  end

  @impl true
  def chat(agent, message, opts) do
    # Store the user's message
    {:ok, _} = Lux.Memory.SimpleMemory.add(
      agent.memory_pid,
      message,
      :interaction,
      %{role: :user}
    )

    case super(agent, message, opts) do
      {:ok, response} = ok ->
        # Store the assistant's response
        {:ok, _} = Lux.Memory.SimpleMemory.add(
          agent.memory_pid,
          response,
          :interaction,
          %{role: :assistant}
        )
        ok
      error -> error
    end
  end
end
```

### LLM Configuration
Control how your agent interacts with language models:

```elixir
llm_config = %{
  # API configuration
  api_key: Lux.Config.openai_api_key(),
  model: Application.get_env(:lux, :open_ai_models)[:default],
  
  # Response characteristics
  temperature: 0.7,        # 0.0-1.0: lower = more focused, higher = more creative
  
  # System messages for personality
  messages: [
    %{
      role: "system",
      content: "You are a helpful assistant..."
    }
  ]
}
```

### Structured Responses
Define schemas to get structured responses from your agent:

```elixir
defmodule MyApp.Schemas.ResponseSchema do
  use Lux.SignalSchema,
    schema: %{
      type: :object,
      properties: %{
        message: %{type: :string, description: "The content of the response"}
      },
      required: [:message]
    }
end

defmodule MyApp.Agents.StructuredAssistant do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    llm_config = %{
      api_key: opts[:api_key] || Lux.Config.openai_api_key(),
      model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:default],
      temperature: 0.7,
      messages: [
        %{
          role: "system",
          content: """
          You are #{opts[:name] || "Structured Assistant"}, #{opts[:description] || "an assistant that provides structured responses"}.
          Your goal is: #{opts[:goal] || "Provide clear, structured responses to user queries"}
          """
        }
      ]
    }

    Lux.Agent.new(%{
      name: opts[:name] || "Structured Assistant",
      description: opts[:description] || "An assistant that provides structured responses",
      goal: opts[:goal] || "Provide clear, structured responses to user queries",
      module: __MODULE__,
      llm_config: llm_config
    })
  end
end
```

## Agent Types

### Chat Agent
A simple conversational agent:

```elixir
defmodule MyApp.Agents.ChatAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    llm_config = %{
      api_key: opts[:api_key] || Lux.Config.openai_api_key(),
      model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:default],
      temperature: 0.7,
      messages: [
        %{
          role: "system",
          content: """
          You are #{opts[:name] || "Chat Assistant"}, #{opts[:description] || "a conversational assistant"}.
          Your goal is: #{opts[:goal] || "Engage in helpful dialogue"}
          
          Respond to users in a clear and concise manner.
          """
        }
      ]
    }

    Lux.Agent.new(%{
      name: opts[:name] || "Chat Assistant",
      description: opts[:description] || "A conversational assistant",
      goal: opts[:goal] || "Engage in helpful dialogue",
      module: __MODULE__,
      llm_config: llm_config
    })
  end
end
```

### Personality-Driven Agent
An agent with a distinct personality:

```elixir
defmodule MyApp.Agents.FunAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    llm_config = %{
      api_key: opts[:api_key] || Lux.Config.openai_api_key(),
      model: opts[:model] || Application.get_env(:lux, :open_ai_models)[:default],
      temperature: 0.8,  # Higher temperature for more creative responses
      messages: [
        %{
          role: "system",
          content: """
          You are #{opts[:name] || "Fun Assistant"}, #{opts[:description] || "a playful and witty AI assistant who loves jokes"}.
          Your goal is: #{opts[:goal] || "Make conversations fun and engaging while being helpful"}
          
          Keep your responses light-hearted but still helpful.
          When explaining technical concepts, use fun analogies and examples.
          """
        }
      ]
    }

    Lux.Agent.new(%{
      name: opts[:name] || "Fun Assistant",
      description: opts[:description] || "A playful and witty AI assistant who loves jokes",
      goal: opts[:goal] || "Make conversations fun and engaging while being helpful",
      module: __MODULE__,
      llm_config: llm_config
    })
  end
end
```

## Using Agents

### Starting an Agent
Agents can be started as GenServers:

```elixir
{:ok, pid} = MyApp.Agents.ChatAgent.start_link()
```

### Sending Messages
Chat with your agent:

```elixir
# Basic chat (default timeout is 120 seconds)
{:ok, response} = ChatAgent.send_message(pid, "Hello!")

# With custom timeout
{:ok, response} = ChatAgent.send_message(pid, "Tell me a joke!", timeout: 30_000)
```

### Working with Memory
Access an agent's memory:

```elixir
# Get recent interactions
{:ok, recent} = Lux.Memory.SimpleMemory.recent(agent.memory_pid, 5)

# Search for specific content
{:ok, matches} = Lux.Memory.SimpleMemory.search(agent.memory_pid, "specific topic")

# Get interactions within a time window
start_time = DateTime.utc_now() |> DateTime.add(-3600) # 1 hour ago
end_time = DateTime.utc_now()
{:ok, window} = Lux.Memory.SimpleMemory.window(agent.memory_pid, start_time, end_time)
```

## Best Practices

1. **Agent Design**
   - Give agents clear, focused purposes
   - Use descriptive names and goals
   - Keep system messages concise but informative

2. **Configuration**
   - Use `Lux.Config` for API keys
   - Use application config for model selection
   - Choose appropriate temperature settings
   - Set reasonable timeouts for long-running operations

3. **Error Handling**
   - Handle API errors gracefully
   - Provide meaningful error messages
   - Consider retry strategies for transient failures

4. **Testing**
   - Test agent behavior with different inputs
   - Mock LLM responses in tests
   - Verify structured response handling

```elixir
defmodule MyApp.Agents.ChatAgentTest do
  use ExUnit.Case, async: true

  setup do
    config = %{
      api_key: Application.get_env(:lux, :api_keys)[:integration_openai],
      model: Application.get_env(:lux, :open_ai_models)[:cheapest],
      temperature: 0.0,
      seed: 42
    }

    {:ok, pid} = ChatAgent.start_link(%{llm_config: config})
    {:ok, agent: pid}
  end

  test "can chat with the agent", %{agent: pid} do
    {:ok, response} = ChatAgent.send_message(pid, "Hello!")
    assert is_binary(response)
    assert String.length(response) > 0
  end
end
```

## Advanced Features

### Signal Handling
Agents can process signals from other components:

```elixir
defmodule MyApp.Agents.SignalAwareAgent do
  use Lux.Agent

  @impl true
  def handle_signal(agent, %{schema_id: MyApp.Schemas.TaskSignal} = signal) do
    # Process the task signal
    {:ok, process_task(signal.payload)}
  end

  def handle_signal(_agent, _signal), do: :ignore
end
```

### Component Integration
Combine agents with other Lux components:

```elixir
defmodule MyApp.Agents.SmartAgent do
  use Lux.Agent

  @impl true
  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Smart Assistant",
      prisms: [MyApp.Prisms.DataAnalysis],
      beams: [MyApp.Beams.TaskProcessor],
      lenses: [MyApp.Lenses.DataViewer],
      # ... rest of config ...
    })
  end
end
``` 