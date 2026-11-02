defmodule Lux.YouTube.ContentCreation do
  @moduledoc """
  Unified coordinator for YouTube Content Creation in Lux.

  Provides high-level APIs for:
  - Video script synthesis with retention hooks and chapter pacing (`generate_script/1`)
  - Automated edit timelines, SFX triggers, and B-roll cues (`generate_editing_cues/1`)
  - Thumbnail artistic prompts and End Screen / Info Card layouts (`generate_thumbnail_spec/2`, `build_end_screen_layout/1`, `plan_info_cards/2`)
  - Pedagogical binge playlist curation (`curate_series/2`)
  - Multi-platform derivative content repurposing (`repurpose/2`)
  - Multi-language localization for global distribution (`localize/3`)
  - A/B testing experiment tracking and significance calculation (`create_experiment/3`, `evaluate_experiment/3`)
  - Comprehensive end-to-end pipeline execution (`build_pipeline/1`)
  """

  alias Lux.YouTube.ContentCreation.{
    ContentRepurposer,
    EditingAdvisor,
    ExperimentFramework,
    LocalizationEngine,
    PlaylistCurator,
    ScriptGenerator,
    VisualOptimizer
  }

  defdelegate generate_script(params), to: ScriptGenerator
  defdelegate generate_editing_cues(script_or_sections), to: EditingAdvisor

  defdelegate generate_thumbnail_spec(topic, opts \\ %{}), to: VisualOptimizer
  defdelegate build_end_screen_layout(duration_seconds), to: VisualOptimizer
  defdelegate plan_info_cards(duration_seconds, related_topics), to: VisualOptimizer

  defdelegate curate_series(series_name, videos), to: PlaylistCurator

  defdelegate repurpose(topic, script_data \\ %{}), to: ContentRepurposer

  defdelegate localize(title, description, locales \\ ["es", "de", "ja", "vi"]), to: LocalizationEngine, as: :localize_package

  defdelegate create_experiment(hypothesis, var_a, var_b), to: ExperimentFramework
  defdelegate evaluate_experiment(exp, data_a, data_b), to: ExperimentFramework, as: :evaluate_results

  @doc """
  Executes an end-to-end YouTube content creation pipeline from a single topic concept.
  Returns complete production assets ready for creators or autonomous media agents.
  """
  @spec build_pipeline(map() | String.t()) :: map()
  def build_pipeline(input) do
    topic = if is_map(input), do: Map.get(input, :topic, Map.get(input, "topic", "AI Systems")), else: to_string(input)
    format = if is_map(input), do: Map.get(input, :format, Map.get(input, "format", :tutorial)), else: :tutorial
    duration = if is_map(input), do: Map.get(input, :target_minutes, Map.get(input, "target_minutes", 10.0)), else: 10.0

    script = generate_script(%{topic: topic, format: format, target_minutes: duration})
    editing_timeline = generate_editing_cues(script.sections)
    thumbnail_spec = generate_thumbnail_spec(topic, %{badge_text: "MUST WATCH"})
    end_screens = build_end_screen_layout(round(duration * 60))
    info_cards = plan_info_cards(round(duration * 60), ["#{topic} Part 2", "Architecture Overview"])
    repurposed = repurpose(topic, script)
    localizations = localize(script.title, "Full technical guide for #{topic}")

    ab_experiment =
      create_experiment(
        "A curiosity-gap title with bold badge will deliver >25% higher CTR than standard tutorial title",
        %{title: script.title, thumbnail_badge: "MUST WATCH"},
        %{title: "Why 99% Fail at #{topic} (The Brutal Truth)", thumbnail_badge: "FATAL MISTAKE"}
      )

    %{
      topic: topic,
      script: script,
      editing_timeline: editing_timeline,
      visual_assets: %{
        thumbnail: thumbnail_spec,
        end_screens: end_screens,
        info_cards: info_cards
      },
      repurposed_package: repurposed,
      localizations: localizations,
      ab_experiment: ab_experiment,
      status: :production_ready
    }
  end
end
