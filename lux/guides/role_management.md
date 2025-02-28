# Role Management in Lux

This guide explains how to manage roles and assign agents in your Lux companies.

## Role Types

1. **CEO**
   - Every company has one CEO
   - Responsible for evaluating and managing objectives
   - Has leadership capabilities

2. **Members**
   - Regular company members
   - Have specific capabilities
   - Can be assigned to objectives

3. **Contractors** (Future)
   - Specialized external agents
   - Temporary assignments
   - Access to specific objectives only

## Role Assignment

To assign an agent to a role:

```elixir
{:ok, _} = Lux.Company.assign_agent(company, role_id, agent)
```

The agent can be:
- A local module (e.g., `MyApp.Agents.Writer`)
- A remote reference (e.g., `{"agent-123", :research_hub}`)

## Role Capabilities

Each role has specific capabilities that determine what tasks they can perform:

```elixir
defmodule MyApp.Companies.BlogTeam do
  use Lux.Company

  company do
    name "Content Creation Team"
    mission "Create engaging content efficiently"

    has_ceo "Content Director" do
      agent MyApp.Agents.ContentDirector
      goal "Direct content creation and review"
      can "plan"
      can "review"
      can "approve"
    end

    members do
      has_role "Lead Researcher" do
        agent {"researcher-123", :research_hub}
        goal "Research and analyze topics"
        can "research"
        can "analyze"
        can "summarize"
      end
    end
  end
end
```

## Error Handling

If you try to run an objective without required roles:

```elixir
{:ok, objective_id} = Lux.Company.run_objective(
  MyApp.Companies.BlogTeam,
  :create_blog_post,
  %{"topic" => "AI"}
)

# You'll receive an error message
receive do
  {:objective_failed, ^objective_id, {:missing_agent, message}} ->
    IO.puts "Objective failed: #{message}"
end
```

## Best Practices

1. **Role Definition**
   - Define roles with clear, focused capabilities
   - Use descriptive names that reflect the role's purpose
   - Document the role's goal and responsibilities

2. **Agent Assignment**
   - Assign agents that match the role's capabilities
   - Consider using remote agents for specialized tasks
   - Validate agent capabilities before assignment

3. **Error Handling**
   - Check for `:missing_agent` errors when running objectives
   - Provide clear feedback when agent assignment fails
   - Validate role IDs before attempting agent assignment

4. **Dynamic Role Management**
   - Consider implementing agent selection logic
   - Keep track of agent assignments
   - Monitor agent health and performance

## Example Workflow

Here's a complete example of managing roles and running an objective:

```elixir
# Start the company
{:ok, _pid} = Lux.Company.start_link(MyApp.Companies.BlogTeam)

# List all roles
{:ok, roles} = Lux.Company.list_roles(MyApp.Companies.BlogTeam)
[ceo, writer] = roles

# Assign agents to roles
{:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, ceo.id, MyApp.Agents.CEO)
{:ok, _} = Lux.Company.assign_agent(MyApp.Companies.BlogTeam, writer.id, MyApp.Agents.Writer)

# Now the objective can run successfully
{:ok, objective_id} = Lux.Company.run_objective(
  MyApp.Companies.BlogTeam,
  :create_blog_post,
  %{"topic" => "AI"}
)

# Wait for completion
receive do
  {:objective_completed, ^objective_id, results} ->
    IO.puts "Objective completed successfully!"
end
``` 