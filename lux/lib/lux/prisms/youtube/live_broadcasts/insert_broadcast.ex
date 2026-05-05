defmodule Lux.Prisms.YouTube.LiveBroadcasts.InsertBroadcast do
  @moduledoc "Creates scheduled YouTube live broadcasts."

  use Lux.Prism,
    name: "Create YouTube Live Broadcast",
    description: "Creates a YouTube live broadcast with snippet/status/contentDetails",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        scheduled_start_time: %{type: :string},
        privacy_status: %{type: :string, enum: ["private", "public", "unlisted"]},
        enable_auto_start: %{type: :boolean},
        enable_auto_stop: %{type: :boolean}
      },
      required: ["title", "scheduled_start_time"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title),
         {:ok, scheduled_start_time} <- required(params, :scheduled_start_time),
         {:ok, response} <- Client.request(:post, "/liveBroadcasts", %{
           params: %{part: "snippet,status,contentDetails"},
           json: build_body(params, title, scheduled_start_time)
         }) do
      {:ok, normalize(response)}
    end
  end

  defp build_body(params, title, scheduled_start_time) do
    %{
      snippet: %{
        title: title,
        description: value(params, :description),
        scheduledStartTime: scheduled_start_time
      },
      status: %{
        privacyStatus: value(params, :privacy_status, "private"),
        selfDeclaredMadeForKids: value(params, :self_declared_made_for_kids, false)
      },
      contentDetails: %{
        enableAutoStart: value(params, :enable_auto_start, false),
        enableAutoStop: value(params, :enable_auto_stop, false),
        enableDvr: value(params, :enable_dvr, true)
      }
    }
  end

  defp normalize(response) do
    snippet = response["snippet"] || %{}
    status = response["status"] || %{}

    %{
      id: response["id"],
      title: snippet["title"],
      lifecycle_status: status["lifeCycleStatus"],
      privacy_status: status["privacyStatus"]
    }
  end

  defp required(params, key) do
    case value(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp value(params, key, default \\ nil), do: Map.get(params, key) || Map.get(params, to_string(key)) || default
end
