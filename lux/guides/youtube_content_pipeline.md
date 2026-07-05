# YouTube Content Creation Pipeline

This guide showcases the fully automated YouTube Content Creation Pipeline implemented using the `Lux.Company` abstraction. The pipeline handles everything from script ideation to thumbnail creation, metadata management, and A/B testing plans.

## Overview

The `YouTubePipeline` company (`Lux.Companies.YouTubePipeline`) coordinates several specialized agents to produce optimized content:

- **Script Generator (Content Director)**: Serves as the CEO of the pipeline. It produces high-retention hooks and comprehensive scripts tailored to specific audience demographics.
- **Visual Optimizer**: Recommends engaging visual pacing, thumbnail prompts, and b-roll placements.
- **Metadata Manager**: Uses SEO best practices to generate highly searchable titles, descriptions, and tag sets.
- **Content Tester**: Develops rigorous A/B testing frameworks, generating distinct variations of titles and thumbnails with clear success metrics.

## Example Workflow

To execute the entire pipeline, you create the company and dispatch the `:create_optimized_video` objective.

```elixir
alias Lux.Companies.YouTubePipeline

# Start the company and register it with a hub
{:ok, pid} = Lux.Company.start_link(YouTubePipeline, %{
  name: "My Content Team",
  hub: :my_company_hub
})

# Run the objective
{:ok, signal} = Lux.Company.run_objective(pid, :create_optimized_video, %{
  "topic" => "Elixir for Beginners: Agentic Workflows",
  "target_audience" => %{
    "age_range" => "18-35",
    "interests" => ["programming", "AI", "software engineering"]
  }
})

# You can then monitor the objective's progress
objective_id = signal.payload["objective_id"] || signal.payload["id"]
{:ok, status} = Lux.Company.get_objective_status(pid, objective_id)
```

## Agents and Capabilities

### 1. Script Generator (`Lux.Agents.YouTube.ScriptGenerator`)
Generates scripts, hooks, and video outlines.
**Capabilities**: `[:script_generation, :hook_writing, :content_structuring]`

### 2. Visual Optimizer (`Lux.Agents.YouTube.VisualOptimizer`)
Proposes visual content strategies.
**Capabilities**: `[:thumbnail_ideation, :broll_suggestion, :pacing_analysis]`

### 3. Metadata Manager (`Lux.Agents.YouTube.MetadataManager`)
Optimizes metadata for YouTube algorithms.
**Capabilities**: `[:seo_optimization, :tag_generation, :description_writing]`

### 4. Content Tester (`Lux.Agents.YouTube.ContentTester`)
Designs experiments to test performance.
**Capabilities**: `[:ab_testing, :performance_analysis, :variation_generation]`

## Extending the Pipeline
Because the pipeline uses the flexible `Lux.Company` and `Lux.Agent` architecture, you can easily integrate existing prisms like `Lux.Prisms.YouTube.UpdateVideo` or `Lux.Prisms.YouTube.UploadVideo` into new objective steps to enable direct, automated publishing to a YouTube channel once the content generation and approval steps are complete.
