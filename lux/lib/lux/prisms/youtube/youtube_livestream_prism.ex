defmodule Lux.Prisms.YouTube.YouTubeLivestreamPrism do
  @moduledoc """
  A prism for managing YouTube live streams - create, start, stop, monitor.
  """

  use Lux.Prism,
    name: "YouTube Livestream Manager",
    description: "Manages YouTube live broadcasts via YouTube Data API v3",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "start", "stop", "status", "list"]},
        broadcast_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        scheduled_start: %{type: :string},
        privacy: %{type: :string, enum: ["public", "private", "unlisted"], default: "public"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        broadcast: %{type: :object},
        broadcasts: %{type: :array}
      },
      required: ["status"]
    }

  require Logger

  @api "https://www.googleapis.com/youtube/v3"

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key() do
      case input.action do
        "create" -> create_broadcast(api_key, input)
        "start"  -> transition_broadcast(api_key, input.broadcast_id, "live")
        "stop"   -> transition_broadcast(api_key, input.broadcast_id, "complete")
        "status" -> get_broadcast(api_key, input.broadcast_id)
        "list"   -> list_broadcasts(api_key)
        _        -> {:error, "Unknown action: #{input.action}"}
      end
    end
  end

  defp get_api_key do
    key = Lux.Config.get(:youtube_api_key) || System.get_env("YOUTUBE_API_KEY")
    if key, do: {:ok, key}, else: {:error, "YouTube API key not configured"}
  rescue
    _ -> {:error, "YouTube API key not configured"}
  end

  defp create_broadcast(api_key, input) do
    body = %{
      snippet: %{
        title: Map.get(input, :title, "New Livestream"),
        description: Map.get(input, :description, ""),
        scheduledStartTime: Map.get(input, :scheduled_start, DateTime.utc_now() |> DateTime.to_iso8601())
      },
      status: %{privacyStatus: Map.get(input, :privacy, "public")},
      contentDetails: %{enableAutoStart: false, enableAutoStop: false}
    }
    case Req.post("#{@api}/liveBroadcasts?part=snippet,status,contentDetails&key=#{api_key}", json: body) do
      {:ok, %{status: 200, body: b}} -> {:ok, %{status: "success", broadcast: parse_broadcast(b)}}
      {:ok, %{status: s, body: b}}   -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r}                    -> {:error, inspect(r)}
    end
  end

  defp transition_broadcast(api_key, broadcast_id, life_cycle_status) do
    case Req.post("#{@api}/liveBroadcasts/transition?broadcastStatus=#{life_cycle_status}&id=#{broadcast_id}&part=status&key=#{api_key}", json: %{}) do
      {:ok, %{status: 200, body: b}} -> {:ok, %{status: "success", broadcast: parse_broadcast(b)}}
      {:ok, %{status: s, body: b}}   -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r}                    -> {:error, inspect(r)}
    end
  end

  defp get_broadcast(api_key, broadcast_id) do
    case Req.get("#{@api}/liveBroadcasts", params: %{part: "snippet,status", id: broadcast_id, key: api_key}) do
      {:ok, %{status: 200, body: %{"items" => [b | _]}}} -> {:ok, %{status: "success", broadcast: parse_broadcast(b)}}
      {:ok, %{status: 200}} -> {:error, "Broadcast not found"}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp list_broadcasts(api_key) do
    case Req.get("#{@api}/liveBroadcasts", params: %{part: "snippet,status", mine: true, key: api_key}) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, %{status: "success", broadcasts: Enum.map(body["items"] || [], &parse_broadcast/1)}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp parse_broadcast(item) do
    %{
      id: item["id"],
      title: get_in(item, ["snippet", "title"]),
      status: get_in(item, ["status", "lifeCycleStatus"]),
      privacy: get_in(item, ["status", "privacyStatus"]),
      scheduled_start: get_in(item, ["snippet", "scheduledStartTime"])
    }
  end
end
