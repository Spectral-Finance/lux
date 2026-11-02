defmodule Lux.YouTube.ContentCreation.PlaylistCurator do
  @moduledoc """
  Clusters video titles into bingeable playlists, plans watch-time sequencing,
  and generates SEO metadata to optimize YouTube's suggested video algorithm.
  """

  @type curated_playlist :: %{
          playlist_title: String.t(),
          category: String.t(),
          description: String.t(),
          ordered_videos: list(%{position: non_neg_integer(), title: String.t(), role: String.t()}),
          projected_binge_multiplier: float()
        }

  @doc """
  Organizes a list of videos into an ordered, high-retention playlist sequence.
  """
  @spec curate_series(String.t(), list(String.t()) | list(map())) :: curated_playlist()
  def curate_series(series_name, videos) when is_list(videos) do
    normalized_videos =
      Enum.map(videos, fn v ->
        if is_map(v), do: Map.get(v, :title, Map.get(v, "title", "Video")), else: to_string(v)
      end)

    # Order videos according to pedagogical flywheel (Fundamentals -> Build -> Scale -> Advanced)
    ordered =
      normalized_videos
      |> Enum.sort_by(&assign_pedagogical_weight/1)
      |> Enum.with_index(1)
      |> Enum.map(fn {title, pos} ->
        %{
          position: pos,
          title: title,
          role: assign_role(pos, length(normalized_videos))
        }
      end)

    description =
      """
      Welcome to the complete #{series_name} series!
      Follow this step-by-step masterclass to learn from first principles to production deployment.
      Bookmark this playlist and watch sequentially for maximum retention and comprehension.
      """
      |> String.trim()

    %{
      playlist_title: "#{series_name}: The Complete Production Series",
      category: "Engineering & Technology",
      description: description,
      ordered_videos: ordered,
      projected_binge_multiplier: 2.8
    }
  end

  defp assign_pedagogical_weight(title) do
    t = String.downcase(title)
    cond do
      String.contains?(t, ["intro", "getting started", "basics", "what is"]) -> 1
      String.contains?(t, ["build", "step-by-step", "tutorial", "guide"]) -> 2
      String.contains?(t, ["test", "debug", "validate"]) -> 3
      String.contains?(t, ["scale", "optimize", "production", "benchmark"]) -> 4
      true -> 5
    end
  end

  defp assign_role(1, _total), do: "Foundation / Broad Funnel Gateway"
  defp assign_role(pos, total) when pos == total, do: "Capstone Project / Advanced Synthesis"
  defp assign_role(_pos, _total), do: "Core Technical Deep Dive"
end
