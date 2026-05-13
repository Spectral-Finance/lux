# YouTube Content Creation Pipeline

`Lux.Integrations.YouTube.ContentPipeline` converts a channel brief into a
production-ready plan for YouTube content creation. It is deterministic and does
not call external services, so it can run in agents, CI, and local planning
sessions without API credentials.

```elixir
{:ok, pipeline} =
  Lux.Integrations.YouTube.ContentPipeline.run(%{
    topic: "on-chain wallet security",
    target_audience: "crypto founders",
    goal: "reduce signing mistakes before launch",
    duration_minutes: 10,
    keywords: ["wallet security", "hardware wallets", "transaction simulation"],
    languages: ["en", "es"],
    existing_playlists: ["Security for crypto founders"]
  })
```

The returned pipeline includes:

* Script outline with hook, sections, retention beats, and CTA
* Automated editing suggestions for pacing, b-roll, captions, and quality checks
* Thumbnail creative variants and on-screen visual guidance
* Metadata plan with title variants, description, tags, chapters, cards, and end screen
* Playlist organization and related playlist recommendations
* Localization tasks for each requested language
* Repurposing plan for Shorts, social posts, newsletter, and blog outline
* A/B testing plan for title, thumbnail, and CTA experiments
* Production handoff checklist

Agents can use the prism wrapper when they need an action surface:

```elixir
Lux.Prisms.YouTube.CreateContentPipeline.run(%{
  "topic" => "on-chain wallet security",
  "target_audience" => "crypto founders",
  "goal" => "reduce signing mistakes before launch"
})
```

Because the output is plain Elixir data, follow-up agents can pass the script
plan to writers, the visual plan to designers, the metadata plan to channel
managers, and the testing plan to analytics workflows.
