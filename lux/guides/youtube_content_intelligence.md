# YouTube Content Intelligence System

The YouTube Content Intelligence System is a multi-agent application built on top of the Lux framework. It automates the process of analyzing, optimizing, and strategizing content for YouTube channels.

## Core Features
- **Video performance analytics**: Analyzes past video performance using heuristic scoring to predict success.
- **Audience engagement analysis**: Determines audience retention and loyalty.
- **Content recommendation engine**: Ranks candidate topics using a deterministic baseline model based on channel CTR, retention, and audience fit.
- **Optimal posting time prediction**: Suggests the best times to post for a given demographic.
- **Title and thumbnail optimization**: Generates highly clickable titles and provides visual thumbnail ideas.
- **Tag optimization**: Creates SEO-optimized tags based on trends and the specific video topic.
- **Description generation**: Drafts engaging video descriptions incorporating generated tags.
- **Trending topic analysis**: Analyzes current niche trends.

## Components

The system is encapsulated within the `Lux.YouTube.YouTubeIntelligence` company, which employs a team of specialized agents:

1. **Strategy Director (CEO)**:
   - Agent: `StrategyAgent`
   - Role: Oversees channel strategy, recommends content, and analyzes trends. Uses the `ContentRecommendationPrism`.

2. **Data Analyst**:
   - Agent: `AnalyticsAgent`
   - Role: Analyzes video performance and audience engagement. Uses the `PerformanceAnalyticsPrism`.

3. **Content Optimizer**:
   - Agent: `OptimizationAgent`
   - Role: Optimizes content metadata (title, tags, description) and predicts posting times. Uses the `MetadataOptimizationPrism`.

## Example Usage

You can run the content optimization workflow by initializing the company and executing the `:optimize_content_workflow` objective.

```elixir
# 1. Start the Hub
{:ok, hub_pid} = Lux.Company.Hub.Local.start_link(name: :my_hub)

# 2. Get configuration and Start the Company
company_config = Lux.YouTube.YouTubeIntelligence.view()
{:ok, company_pid} = Lux.Company.start_link(Lux.YouTube.YouTubeIntelligence, %{
  name: company_config.name,
  hub: :my_hub
})

Lux.Company.Hub.Local.register_company(company_config, :my_hub)

# 3. Run the objective
{:ok, objective} = Lux.Company.run_objective(company_pid, :optimize_content_workflow, %{
  "topic" => "Building AI Agents with Elixir",
  "niche" => "Programming",
  "video_data" => [
    %{
      "video_id" => "vid_123",
      "views" => 15000,
      "watch_time_hours" => 1200,
      "ctr" => 5.2,
      "avg_view_duration" => 6.5
    }
  ]
})

# 4. Check status
objective_id = objective.payload["id"]
{:ok, status} = Lux.Company.get_objective_status(company_pid, objective_id)
```

## Integration Tests

To run the integration tests showcasing the content optimization workflow:

```bash
mix test test/integration/youtube/youtube_intelligence_test.exs
```
