defmodule Lux.Prisms.YouTube.Live.CreateBroadcast do
  @moduledoc """
  Creates a YouTube live broadcast resource.
  """

  use Lux.Prism,
    name: "Create YouTube Live Broadcast",
    description: "Creates a scheduled YouTube live broadcast",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Broadcast title"},
        scheduled_start_time: %{
          type: :string,
          description: "Scheduled start time in RFC3339 format"
        },
        description: %{type: :string, description: "Broadcast description"},
        privacy_status: %{
          type: :string,
          enum: ["private", "public", "unlisted"],
          description: "Broadcast privacy status"
        },
        enable_auto_start: %{type: :boolean, description: "Whether YouTube should auto-start"},
        enable_auto_stop: %{type: :boolean, description: "Whether YouTube should auto-stop"},
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Created broadcast ID"},
        title: %{type: :string, description: "Broadcast title"}
      },
      required: ["broadcast_id", "title"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, title} <- validate_string(params, :title),
         {:ok, scheduled_start_time} <- validate_string(params, :scheduled_start_time) do
      broadcast = %{
        snippet: %{
          title: title,
          description: Map.get(params, :description, ""),
          scheduledStartTime: scheduled_start_time
        },
        status: %{privacyStatus: Map.get(params, :privacy_status, "private")},
        contentDetails: %{
          enableAutoStart: Map.get(params, :enable_auto_start, false),
          enableAutoStop: Map.get(params, :enable_auto_stop, true)
        }
      }

      case Client.insert_live_broadcast(broadcast, request_opts(params)) do
        {:ok, %{"id" => broadcast_id}} -> {:ok, %{broadcast_id: broadcast_id, title: title}}
        {:error, error} -> {:error, "Failed to create YouTube broadcast: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
