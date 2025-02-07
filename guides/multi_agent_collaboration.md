# Multi-Agent Collaboration Guide

This guide demonstrates how to create and coordinate multiple agents working together in Lux.

## Basic Concepts

Multi-agent collaboration in Lux is built on several key components:

1. **Agent Registry**: Central system for discovering and tracking agents
2. **Capabilities**: Tags that describe what an agent can do
3. **Status Tracking**: Monitoring agent availability and workload
4. **Message Passing**: Communication between agents

## Creating Collaborative Agents

Here's an example of creating two agents that work together:

```elixir
defmodule MyApp.Agents.Researcher do
  use Lux.Agent

  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Research Assistant",
      description: "Specialized in research and analysis",
      goal: "Find and analyze information accurately",
      capabilities: [:research, :analysis],
      llm_config: %{
        model: "gpt-4",
        temperature: 0.7,
        messages: [
          %{
            role: "system",
            content: """
            You are a Research Assistant specialized in finding and analyzing information.
            Work with other agents to provide comprehensive research results.
            """
          }
        ]
      }
    })
  end
end

defmodule MyApp.Agents.Writer do
  use Lux.Agent

  def new(opts \\ %{}) do
    Lux.Agent.new(%{
      name: "Content Writer",
      description: "Specialized in content creation",
      goal: "Create engaging content from research",
      capabilities: [:writing, :editing],
      llm_config: %{
        model: "gpt-4",
        temperature: 0.7,
        messages: [
          %{
            role: "system",
            content: """
            You are a Content Writer specialized in creating engaging content.
            Work with researchers to transform their findings into compelling articles.
            """
          }
        ]
      }
    })
  end
end
```

## Starting and Registering Agents

```elixir
# Start the agents
{:ok, researcher_pid} = MyApp.Agents.Researcher.start_link()
{:ok, writer_pid} = MyApp.Agents.Writer.start_link()

# Get agent states
researcher = :sys.get_state(researcher_pid)
writer = :sys.get_state(writer_pid)

# Register agents with their capabilities
:ok = Lux.Agent.Registry.register(researcher, researcher_pid, [:research, :analysis])
:ok = Lux.Agent.Registry.register(writer, writer_pid, [:writing, :editing])
```

## Finding and Using Agents

```elixir
# Find agents by capability
research_agents = Lux.Agent.Registry.find_by_capability(:research)
writing_agents = Lux.Agent.Registry.find_by_capability(:writing)

# Get specific agent info
{:ok, researcher_info} = Lux.Agent.Registry.get_agent_info(researcher.id)
```

## Coordinating Work Between Agents

Here's an example of how to coordinate work between a researcher and writer:

```elixir
# 1. Start with a research task
{:ok, research_response} = 
  MyApp.Agents.Researcher.send_message(
    researcher_pid,
    "Research the impact of AI on healthcare"
  )

# 2. Update researcher status to busy
:ok = Lux.Agent.Registry.update_status(researcher.id, :busy)

# 3. Send research to writer for content creation
{:ok, article} = 
  MyApp.Agents.Writer.send_message(
    writer_pid,
    """
    Create an engaging blog post based on this research:
    #{research_response}
    """
  )

# 4. Mark researcher as available again
:ok = Lux.Agent.Registry.update_status(researcher.id, :available)
```

## Best Practices

1. **Status Management**
   - Always update agent status when starting/finishing work
   - Check agent availability before sending tasks
   - Handle offline agents gracefully

2. **Capability Design**
   - Use specific, descriptive capability names
   - Avoid overlapping capabilities
   - Document expected inputs/outputs for each capability

3. **Error Handling**
   - Handle agent unavailability
   - Implement retry mechanisms for failed communications
   - Monitor agent health

## Example: Research and Writing Pipeline

Here's a complete example of a research and writing pipeline:

```elixir
defmodule MyApp.Workflows.ContentCreation do
  alias Lux.Agent.Registry
  
  def create_article(topic) do
    # Find available researcher
    case Registry.find_by_capability(:research) do
      [%{agent: researcher, pid: researcher_pid, status: :available} | _] ->
        # Update researcher status
        :ok = Registry.update_status(researcher.id, :busy)
        
        # Get research
        {:ok, research} = MyApp.Agents.Researcher.send_message(
          researcher_pid,
          "Research #{topic} comprehensively"
        )
        
        # Mark researcher as available
        :ok = Registry.update_status(researcher.id, :available)
        
        # Find available writer
        case Registry.find_by_capability(:writing) do
          [%{pid: writer_pid} | _] ->
            # Create content
            {:ok, article} = MyApp.Agents.Writer.send_message(
              writer_pid,
              """
              Create an engaging article based on this research:
              #{research}
              """
            )
            
            {:ok, article}
            
          [] ->
            {:error, :no_writers_available}
        end
        
      [] ->
        {:error, :no_researchers_available}
    end
  end
end
```

## Advanced Topics

### Scaling Agent Teams

As your system grows, consider:
- Implementing load balancing between similar agents
- Adding specialized agents for specific tasks
- Using agent pools for high-demand capabilities

### Monitoring and Debugging

Track agent collaboration using:
- Agent status history
- Task completion metrics
- Communication logs

### Security Considerations

- Implement authentication between agents
- Validate message contents
- Rate limit agent interactions
- Monitor resource usage

## Next Steps

1. Implement more sophisticated collaboration patterns
2. Add error recovery mechanisms
3. Create specialized agent teams
4. Implement performance monitoring 