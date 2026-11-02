defmodule Lux.Prisms.YouTubeContentCreationPrism do
  @moduledoc """
  A Prism for autonomous agents to plan, script, optimize, repurpose, and localize
  YouTube video content pipelines end-to-end.

  ## Examples

      iex> Lux.Prisms.YouTubeContentCreationPrism.run(%{
      ...>   action: "generate_script",
      ...>   payload: %{topic: "Autonomous Multi-Agent Systems in Elixir"}
      ...> })
      {:ok, %{action: "generate_script", result: %{title: "...", hook: "...", ...}}}
  """

  use Lux.Prism,
    name: "YouTube Content Creation Prism",
    description: "Generates high-retention video scripts, editing timelines, thumbnail specs, multi-platform repurposed assets, and A/B experiments",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: [
            "generate_script",
            "advise_editing",
            "optimize_visuals",
            "curate_playlist",
            "repurpose_content",
            "localize",
            "setup_experiment",
            "evaluate_experiment",
            "build_pipeline"
          ],
          description: "Content creation pipeline action to execute"
        },
        payload: %{
          type: :object,
          description: "Payload data corresponding to chosen action"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        result: %{type: :object}
      },
      required: ["action", "result"]
    }

  alias Lux.YouTube.ContentCreation

  def handler(input, _context) do
    action = Map.get(input, :action) || Map.get(input, "action", "build_pipeline")
    payload = Map.get(input, :payload) || Map.get(input, "payload", %{})

    case execute_action(action, payload) do
      {:ok, result} ->
        {:ok, %{action: action, result: result}}

      {:error, reason} ->
        {:error, "YouTubeContentCreationPrism error on action '#{action}': #{inspect(reason)}"}
    end
  end

  defp execute_action("generate_script", payload) do
    {:ok, ContentCreation.generate_script(payload)}
  end

  defp execute_action("advise_editing", payload) do
    sections = Map.get(payload, :sections, Map.get(payload, "sections", []))
    {:ok, ContentCreation.generate_editing_cues(sections)}
  end

  defp execute_action("optimize_visuals", payload) do
    topic = Map.get(payload, :topic, Map.get(payload, "topic", "Tech Video"))
    duration = Map.get(payload, :duration_seconds, Map.get(payload, "duration_seconds", 600))
    thumb = ContentCreation.generate_thumbnail_spec(topic, payload)
    ends = ContentCreation.build_end_screen_layout(duration)
    cards = ContentCreation.plan_info_cards(duration, ["Next Tutorial"])

    {:ok, %{thumbnail: thumb, end_screens: ends, info_cards: cards}}
  end

  defp execute_action("curate_playlist", payload) do
    name = Map.get(payload, :series_name, Map.get(payload, "series_name", "Series"))
    videos = Map.get(payload, :videos, Map.get(payload, "videos", []))
    {:ok, ContentCreation.curate_series(name, videos)}
  end

  defp execute_action("repurpose_content", payload) do
    topic = Map.get(payload, :topic, Map.get(payload, "topic", "Engineering Deep Dive"))
    {:ok, ContentCreation.repurpose(topic, payload)}
  end

  defp execute_action("localize", payload) do
    title = Map.get(payload, :title, Map.get(payload, "title", "Guide"))
    desc = Map.get(payload, :description, Map.get(payload, "description", "Tutorial"))
    locales = Map.get(payload, :locales, Map.get(payload, "locales", ["es", "de", "ja", "vi"]))
    {:ok, %{localizations: ContentCreation.localize(title, desc, locales)}}
  end

  defp execute_action("setup_experiment", payload) do
    hypothesis = Map.get(payload, :hypothesis, Map.get(payload, "hypothesis", "Testing CTR lift"))
    var_a = Map.get(payload, :variant_a, Map.get(payload, "variant_a", %{title: "A"}))
    var_b = Map.get(payload, :variant_b, Map.get(payload, "variant_b", %{title: "B"}))
    {:ok, ContentCreation.create_experiment(hypothesis, var_a, var_b)}
  end

  defp execute_action("evaluate_experiment", payload) do
    exp = Map.get(payload, :experiment, Map.get(payload, "experiment", %{}))
    data_a = Map.get(payload, :data_a, Map.get(payload, "data_a", %{}))
    data_b = Map.get(payload, :data_b, Map.get(payload, "data_b", %{}))
    {:ok, ContentCreation.evaluate_experiment(exp, data_a, data_b)}
  end

  defp execute_action("build_pipeline", payload) do
    {:ok, ContentCreation.build_pipeline(payload)}
  end

  defp execute_action(unknown, _payload) do
    {:error, "Unknown action: #{unknown}"}
  end
end
