defmodule Lux.Lenses.YouTube.LiveStreams.ListStreams do
  @moduledoc "Lists YouTube live streams with ingestion and health details."

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Live Streams",
    description: "Lists YouTube live streams for the authenticated user or by stream ID",
    url: "https://www.googleapis.com/youtube/v3/liveStreams",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        mine: %{type: :boolean},
        id: %{type: :string},
        part: %{type: :string},
        max_results: %{type: :integer, minimum: 1, maximum: 50},
        page_token: %{type: :string}
      }
    }

  def before_focus(params) do
    params
    |> put_default(:part, "snippet,cdn,status")
    |> rename(:max_results, :maxResults)
    |> rename(:page_token, :pageToken)
  end

  def after_focus(%{"items" => items} = response) when is_list(items) do
    result = %{streams: Enum.map(items, &normalize_stream/1)}

    result = maybe_put(result, :next_page_token, response["nextPageToken"])
    result = maybe_put(result, :page_info, normalize_page_info(response["pageInfo"]))
    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(response), do: {:ok, response}

  defp normalize_stream(stream) do
    snippet = stream["snippet"] || %{}
    cdn = stream["cdn"] || %{}
    ingestion = cdn["ingestionInfo"] || %{}
    status = stream["status"] || %{}
    health = status["healthStatus"] || %{}

    %{
      id: stream["id"],
      title: snippet["title"],
      description: snippet["description"],
      ingestion_type: cdn["ingestionType"],
      resolution: cdn["resolution"],
      frame_rate: cdn["frameRate"],
      ingestion_address: ingestion["ingestionAddress"],
      backup_ingestion_address: ingestion["backupIngestionAddress"],
      stream_name: ingestion["streamName"],
      stream_status: status["streamStatus"],
      health_status: health["status"]
    }
  end

  defp normalize_page_info(nil), do: nil

  defp normalize_page_info(page_info) do
    %{
      total_results: page_info["totalResults"],
      results_per_page: page_info["resultsPerPage"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_default(params, key, value) do
    if Map.has_key?(params, key) or Map.has_key?(params, to_string(key)) do
      params
    else
      Map.put(params, key, value)
    end
  end

  defp rename(params, from, to) do
    string_from = to_string(from)

    cond do
      Map.has_key?(params, from) ->
        {value, params} = Map.pop(params, from)
        Map.put(params, to, value)

      Map.has_key?(params, string_from) ->
        {value, params} = Map.pop(params, string_from)
        Map.put(params, to, value)

      true ->
        params
    end
  end
end
