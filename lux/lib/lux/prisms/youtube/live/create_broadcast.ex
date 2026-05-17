defmodule Lux.Prisms.YouTube.Live.CreateBroadcast do
  @moduledoc """
  Creates a YouTube live broadcast.
  """

  use Lux.Prism,
    name: "Create YouTube Live Broadcast",
    description: "Schedules a YouTube live broadcast with status and monitor-stream settings",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Broadcast title"},
        scheduled_start_time: %{type: :string, description: "ISO8601 scheduled start time"},
        description: %{type: :string, description: "Broadcast description"},
        privacy_status: %{
          type: :string,
          enum: ["private", "public", "unlisted"],
          default: "private"
        },
        enable_monitor_stream: %{type: :boolean, default: true}
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        title: %{type: :string},
        lifecycle_status: %{type: :string},
        live_chat_id: %{type: :string}
      },
      required: ["id", "title"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  def handler(params, _agent) do
    with {:ok, title} <- required(params, :title),
         {:ok, scheduled_start_time} <- required(params, :scheduled_start_time) do
      body = %{
        snippet: %{
          title: title,
          description: params[:description] || "",
          scheduledStartTime: scheduled_start_time
        },
        status: %{
          privacyStatus: params[:privacy_status] || "private"
        },
        contentDetails: %{
          monitorStream: %{
            enableMonitorStream: Map.get(params, :enable_monitor_stream, true)
          }
        }
      }

      opts = [
        token: params[:token],
        params: %{part: "snippet,status,contentDetails"},
        json: body,
        plug: params[:plug]
      ]

      case Client.request(:post, "/liveBroadcasts", opts) do
        {:ok, response} -> {:ok, LiveStream.normalize_broadcast(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
