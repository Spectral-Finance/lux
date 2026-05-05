defmodule Lux.Prisms.YouTube.LiveBroadcasts.UpdateBroadcast do
  @moduledoc "Updates metadata, privacy, and content settings for a YouTube live broadcast."

  use Lux.Prism,
    name: "Update YouTube Live Broadcast",
    description: "Updates YouTube live broadcast metadata, privacy, and content settings",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        scheduled_start_time: %{type: :string},
        privacy_status: %{type: :string, enum: ["private", "public", "unlisted"]},
        enable_auto_start: %{type: :boolean},
        enable_auto_stop: %{type: :boolean}
      },
      required: ["id"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, id} <- required(params, :id),
         {:ok, response} <- Client.request(:put, "/liveBroadcasts", %{
           params: %{part: "snippet,status,contentDetails"},
           json: build_body(params, id)
         }) do
      {:ok, normalize(response)}
    end
  end

  defp build_body(params, id) do
    %{
      id: id,
      snippet: compact(%{
        title: value(params, :title),
        description: value(params, :description),
        scheduledStartTime: value(params, :scheduled_start_time)
      }),
      status: compact(%{
        privacyStatus: value(params, :privacy_status),
        selfDeclaredMadeForKids: value(params, :self_declared_made_for_kids)
      }),
      contentDetails: compact(%{
        enableAutoStart: value(params, :enable_auto_start),
        enableAutoStop: value(params, :enable_auto_stop),
        enableDvr: value(params, :enable_dvr)
      })
    }
    |> Enum.reject(fn {_key, value} -> value == %{} end)
    |> Map.new()
  end

  defp normalize(response) do
    snippet = response["snippet"] || %{}
    status = response["status"] || %{}
    details = response["contentDetails"] || %{}

    %{
      id: response["id"],
      title: snippet["title"],
      lifecycle_status: status["lifeCycleStatus"],
      privacy_status: status["privacyStatus"],
      bound_stream_id: details["boundStreamId"]
    }
  end

  defp compact(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp required(params, key) do
    case value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp value(params, key, default \\ nil), do: Map.get(params, key) || Map.get(params, to_string(key)) || default
end
