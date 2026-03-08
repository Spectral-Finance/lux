# YouTube Content Creation Pipeline Guide

Automated content creation and optimization for YouTube channels.

## Script Generator

```elixir
{:ok, pid} = ScriptGenerator.start_link()

# Generate from template
{:ok, script} = ScriptGenerator.generate(pid, %{
  title: "Learn Elixir in 10 Minutes",
  topic: "Elixir Programming",
  template: :tutorial  # or :review
})
# Returns sections with timings, auto-generated tags

# Translate
{:ok, zh_script} = ScriptGenerator.translate(pid, script.id, "zh")

# Custom templates
ScriptGenerator.add_template(pid, %{name: :shorts, sections: [...]})
```

## Content Optimizer

```elixir
# Thumbnail optimization
{:ok, result} = ContentOptimizer.optimize_thumbnail(%{
  width: 1280, height: 720, file_size_kb: 500, has_text: true, has_face: true
})
# => %{score: 100, optimized: true, issues: []}

# End screens
{:ok, es} = ContentOptimizer.generate_end_screen(%{video_duration: 600, next_video: "abc"})

# Cards
{:ok, cards} = ContentOptimizer.generate_cards(%{video_duration: 600, links: [...]})

# Metadata SEO
{:ok, meta} = ContentOptimizer.optimize_metadata(%{title: "...", description: "...", tags: [...]})
```

## Playlist Organizer

```elixir
{:ok, pid} = PlaylistOrganizer.start_link()
{:ok, pl} = PlaylistOrganizer.create_playlist(pid, %{title: "Tutorial Series"})
PlaylistOrganizer.add_video(pid, pl.id, %{id: "v1", title: "Part 1"})
PlaylistOrganizer.reorder(pid, pl.id, "v2", 0)

# Auto-categorize by tags
{:ok, categories} = PlaylistOrganizer.auto_categorize(pid, videos)
```

## A/B Testing

```elixir
{:ok, pid} = ABTesting.start_link()
{:ok, exp} = ABTesting.create_experiment(pid, %{
  name: "Thumbnail test", variants: ["A", "B"], video_id: "v1"
})

ABTesting.record_impression(pid, exp.id, "A")
ABTesting.record_click(pid, exp.id, "A")

{:ok, results} = ABTesting.get_results(pid, exp.id)
{:ok, winner} = ABTesting.conclude(pid, exp.id)
```
