defmodule Lux.Prisms.YouTube.VideoMetadataPrism do
  @moduledoc """
  A prism that flattens a YouTube video resource into clean, indexable metadata
  (lux issue #78 — "YouTube Prism implementation", video intelligence).

  Pure and deterministic: given a `videos.list` resource item it extracts a
  flattened record — title, description, tags, duration in seconds, publication
  year, category, channel id and default language — suitable for downstream
  indexing or embedding. No network call is made here.

  ## Examples
      iex> VideoMetadataPrism.handler(%{video: %{
      ...>   id: "v1",
      ...>   snippet: %{title: "Intro", publishedAt: "2024-01-15T10:00:00Z"},
      ...>   contentDetails: %{duration: "PT4M13S"}
      ...> }}, %{})
      {:ok, %{video_id: "v1", title: "Intro", duration_seconds: 253, published_year: 2024}}
  """

  use Lux.Prism,
    name: "YouTube Video Metadata",
    description:
      "Extracts flattened, indexable metadata (title, tags, duration, published year, category, language) from a videos.list resource item",
    input_schema: %{
      type: :object,
      properties: %{video: %{type: :object, description: "A videos.list resource item"}},
      required: ["video"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        tags: %{type: :array},
        duration_seconds: %{type: :integer},
        published_year: %{type: :integer},
        category_id: %{type: :string},
        channel_id: %{type: :string},
        default_language: %{type: :string}
      },
      required: ["video_id", "title"]
    }

  alias Lux.Prisms.YouTube.{IntelUtil, Util}

  def handler(params, _agent) do
    video = Map.get(params, :video) || %{}
    snippet = IntelUtil.section(video, "snippet")
    details = IntelUtil.section(video, "contentDetails")

    tags =
      case IntelUtil.get_field(snippet, "tags") do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        _ -> []
      end

    language =
      IntelUtil.get_field(snippet, "defaultLanguage") ||
        IntelUtil.get_field(snippet, "defaultAudioLanguage") ||
        ""

    result = %{
      video_id: IntelUtil.get_field(video, "id") || "",
      title: IntelUtil.get_field(snippet, "title") || "",
      description: IntelUtil.get_field(snippet, "description") || "",
      tags: tags,
      duration_seconds:
        details |> IntelUtil.get_field("duration") |> IntelUtil.iso8601_to_seconds(),
      published_year:
        snippet |> IntelUtil.get_field("publishedAt") |> IntelUtil.parse_year(),
      category_id: (IntelUtil.get_field(snippet, "categoryId") || "") |> to_string(),
      channel_id: IntelUtil.get_field(snippet, "channelId") || "",
      default_language: language
    }

    {:ok, result}
  end
end