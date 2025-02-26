# Defining Companies in Lux

Companies in Lux are the highest-level organizational units that coordinate agent-based workflows. A company consists of:
- A CEO agent for high-level coordination and decision making
- Member agents with specific roles and capabilities
- Objectives that define executable workflows

## Basic Company Structure

Here's a basic example of defining a company:

```elixir
defmodule MyApp.Companies.BlogTeam do
  use Lux.Company

  company do
    name("Content Creation Lab")
    mission("Create high-quality, research-backed blog content")

    has_ceo "Content Director" do
      agent(MyApp.Agents.ContentDirector)
      goal("Coordinate the team and ensure high-quality content delivery")
      can("plan content strategy")
      can("review and approve content")
    end

    has_member "Research Specialist" do
      agent(MyApp.Agents.Researcher)
      goal("Find and analyze relevant information")
      can("conduct research")
      can("analyze data")
    end

    has_member "Content Writer" do
      agent(MyApp.Agents.Writer)
      goal("Create engaging written content")
      can("write content")
      can("edit content")
    end
  end

  objective :create_blog_post do
    description "Create a well-researched blog post"
    success_criteria "Well-researched content with cited sources, engaging writing style, proper structure, and approved by Content Director"
    steps [
      "Research the topic thoroughly",
      "Create a detailed outline",
      "Write the first draft",
      "Review and edit content"
    ]
  end
end
```

## Company Components

### 1. Company Definition

The `company` block defines the basic structure and metadata:
- `name/1`: Sets the company name
- `mission/1`: Defines the company's mission statement

### 2. Roles

#### CEO Role
The CEO is defined using `has_ceo` and is responsible for coordination and oversight:
```elixir
has_ceo "Role Name" do
  agent(ModuleName)    # The agent module that implements the CEO's behavior
  goal("Description")  # The CEO's primary objective
  can("capability")    # Add capabilities that the CEO possesses
end
```

#### Member Roles
Members are defined using `has_member` and represent specialized agents:
```elixir
has_member "Role Name" do
  agent(ModuleName)    # The agent module that implements the member's behavior
  goal("Description")  # The member's primary objective
  can("capability")    # Add capabilities that the member possesses
end
```

### 3. Objectives

Objectives define workflows that the company can execute:
```elixir
objective :objective_name do
  description "Description of what this objective accomplishes"
  success_criteria "Criteria that must be met for this objective to be considered successful"
  steps [
    "First step description",
    "Second step description",
    "Third step description"
  ]
end
```

## Running a Company

### 1. Starting the Company

To start a company, use the `Lux.Company.start_link/2` function:

```elixir
{:ok, pid} = Lux.Company.start_link(MyApp.Companies.BlogTeam)
```

### 2. Running Objectives

To execute an objective within the company:

```elixir
params = %{
  "topic" => "Introduction to AI",
  "target_audience" => "beginners",
  "tone" => "casual"
}

{:ok, objective_id} = Lux.Company.run_objective(MyApp.Companies.BlogTeam, :create_blog_post, params)
```

## Best Practices

1. **Role Definition**
   - Give each role a clear, focused purpose
   - Define specific capabilities that align with the role's responsibilities
   - Use descriptive names for roles and capabilities

2. **Objective Structure**
   - Break down objectives into clear, sequential steps
   - Make step descriptions actionable and unambiguous
   - Include all necessary input fields
   - Consider the natural workflow of your agents

3. **Agent Implementation**
   - Implement agents that specialize in their assigned capabilities
   - Ensure agents can handle the tasks described in objective steps
   - Use appropriate LLM configurations for each agent's needs

4. **Error Handling**
   - Objectives should validate their inputs
   - Agents should handle task failures gracefully
   - Consider retry strategies for transient failures

## Example: Weather News Team

Here's a complete example of a weather news company:

```elixir
defmodule MyApp.Companies.WeatherNewsTeam do
  use Lux.Company

  company do
    name("Weather News Team")
    mission("Deliver accurate and engaging weather news")

    has_ceo "Editorial Director" do
      agent(MyApp.Agents.Editor)
      goal("Direct weather news coverage and set editorial tone")
      can("plan coverage")
      can("set tone")
      can("review content")
    end

    has_member "Weather Expert" do
      agent(MyApp.Agents.WeatherAnalyst)
      goal("Analyze weather data and provide insights")
      can("analyze weather")
      can("process data")
    end

    has_member "News Writer" do
      agent(MyApp.Agents.NewsPresenter)
      goal("Create engaging weather news scripts")
      can("write scripts")
      can("present news")
    end
  end

  objective :create_weather_report do
    description "Create a comprehensive weather report"
    success_criteria "Accurate weather data analysis, engaging presentation, and approved by Editorial Director"
    steps [
      "Analyze weather data for the area",
      "Create news script with specified tone",
      "Review final content"
    ]
  end
end
```