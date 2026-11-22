defmodule Lux.Prisms.YouTube.SeoAuditPrism do
  @moduledoc """
  A prism that audits a YouTube video's search-engine / discovery optimisation
  (lux issue #78 — "YouTube Prism implementation", SEO intelligence).

  Pure and deterministic: given a `videos.list` resource item and an optional
  target keyword it scores the video 0-100 on the on-platform SEO signals that
  drive discovery — title length, description length, tag presence, keyword
  placement in the title, and a healthy title — and returns concrete
  recommendations for anything weak. No network call is made here.

  ## Examples
      iex> SeoAuditPrism.handler(%{video: %{
      ...>   id: "v1",
      ...>   snippet: %{title: "Sourdough Starter Guide", description: "Learn ...", tags: ["sourdough"]}
      ...> }, target_keyword: "sourdough"}, %{})
      {:ok, %{video_id: "v1", seo_score: 90.0, keyword_in_title: true}}
  """

  use Lux.Prism,
    name: "YouTube SEO Audit",
    description:
      "Scores a YouTube video's discovery/SEO signals and returns recommendations",
    input_schema: %{
      type: :object,
      properties: %{
        video: %{type: :object, description: "A videos.list resource item"},
        target_keyword: %{type: :string, description: "Optional keyword to check placement for"}
      },
      required: ["video"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        seo_score: %{type: :number, description: "0-100 SEO score"},
        title_length: %{type: :integer},
        description_length: %{type: :integer},
        tag_count: %{type: :integer},
        keyword_in_title: %{type: :boolean},
        recommendations: %{type: :array, description: "Actionable improvement hints"}
      },
      required: ["video_id", "seo_score", "recommendations"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    video = Map.get(params, :video) || %{}
    snippet = IntelUtil.section(video, "snippet")
    keyword = params |> Map.get(:target_keyword, "") |> normalize()

    title = IntelUtil.get_field(snippet, "title") || ""
    description = IntelUtil.get_field(snippet, "description") || ""

    tags =
      case IntelUtil.get_field(snippet, "tags") do
        list when is_list(list) -> list
        _ -> []
      end

    title_length = String.length(title)
    description_length = String.length(description)
    tag_count = length(tags)
    keyword_in_title = keyword != "" and String.contains?(String.downcase(title), keyword)

    # Five weighted signals, each worth a fixed number of points (total 100).
    checks = [
      {title_length >= 30 and title_length <= 70, 25, "Title length is outside the ideal 30-70 chars"},
      {description_length >= 250, 25, "Description is short; aim for 250+ chars with detail"},
      {tag_count >= 3, 20, "Add at least 3 relevant tags"},
      {keyword == "" or keyword_in_title, 20, "Target keyword is missing from the title"},
      {title_length >= 15, 10, "Title is very short; be more descriptive"}
    ]

    {score, recs} =
      Enum.reduce(checks, {0, []}, fn {passed?, points, hint}, {acc, recommendations} ->
        if passed? do
          {acc + points, recommendations}
        else
          {acc, recommendations ++ [hint]}
        end
      end)

    result = %{
      video_id: IntelUtil.get_field(video, "id") || "",
      seo_score: score,
      title_length: title_length,
      description_length: description_length,
      tag_count: tag_count,
      keyword_in_title: keyword_in_title,
      recommendations: recs
    }

    {:ok, result}
  end

  defp normalize(nil), do: ""
  defp normalize(keyword) when is_binary(keyword), do: keyword |> String.downcase() |> String.trim()
  defp normalize(keyword), do: keyword |> to_string() |> String.downcase() |> String.trim()
end