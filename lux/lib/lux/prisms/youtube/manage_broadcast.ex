defmodule Lux.Prisms.YouTube.ManageBroadcast do
  @moduledoc "Create and manage YouTube live broadcasts."

  use Lux.Prism,
    name: "YouTube Manage Broadcast",
    description: "Create, update, transition, or delete live broadcasts",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["create", "transition", "update", "delete", "bind"]},
        title: %{type: :string},
        description: %{type: :string},
        scheduled_start: %{type: :string},
        privacy_status: %{type: :string, enum: ["public", "private", "unlisted"]},
        broadcast_id: %{type: :string},
        stream_id: %{type: :string},
        broadcast_status: %{type: :string, enum: ["testing", "live", "complete"]},
        access_token: %{type: :string}
      },
      required: ["action", "access_token"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _context) do
    action = to_s(params, :action)
    token = to_s(params, :access_token)
    plug = params[:plug]

    case action do
      "create" -> create_broadcast(params, token, plug)
      "transition" -> transition_broadcast(params, token, plug)
      "update" -> update_broadcast(params, token, plug)
      "delete" -> delete_broadcast(params, token, plug)
      "bind" -> bind_stream(params, token, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp create_broadcast(params, token, plug) do
    body = %{
      snippet: %{
        title: to_s(params, :title) || "Live Stream",
        description: to_s(params, :description) || "",
        scheduledStartTime: to_s(params, :scheduled_start) || DateTime.utc_now() |> DateTime.to_iso8601()
      },
      status: %{privacyStatus: to_s(params, :privacy_status) || "private"},
      contentDetails: %{
        enableAutoStart: true, enableAutoStop: true, enableDvr: true,
        enableContentEncryption: false, enableEmbed: true,
        recordFromStart: true, startWithSlate: false
      }
    }

    Client.request(:post, "/liveBroadcasts?part=snippet,status,contentDetails", %{
      json: body, auth_type: :oauth2, access_token: token, plug: plug
    })
    |> format(:broadcast)
  end

  defp transition_broadcast(params, token, plug) do
    id = to_s(params, :broadcast_id)
    status = to_s(params, :broadcast_status)

    Client.request(:post, "/liveBroadcasts/transition?broadcastStatus=#{status}&id=#{id}&part=status", %{
      auth_type: :oauth2, access_token: token, plug: plug
    })
    |> format(:broadcast)
  end

  defp update_broadcast(params, token, plug) do
    body = %{
      id: to_s(params, :broadcast_id),
      snippet: %{
        title: to_s(params, :title),
        description: to_s(params, :description)
      }
    }

    Client.request(:put, "/liveBroadcasts?part=snippet", %{
      json: body, auth_type: :oauth2, access_token: token, plug: plug
    })
    |> format(:broadcast)
  end

  defp delete_broadcast(params, token, plug) do
    id = to_s(params, :broadcast_id)
    Client.request(:delete, "/liveBroadcasts?id=#{id}", %{
      auth_type: :oauth2, access_token: token, plug: plug
    })
    |> case do
      {:ok, _} -> {:ok, %{deleted: true, broadcast_id: id}}
      error -> error
    end
  end

  defp bind_stream(params, token, plug) do
    id = to_s(params, :broadcast_id)
    stream_id = to_s(params, :stream_id)

    Client.request(:post, "/liveBroadcasts/bind?id=#{id}&streamId=#{stream_id}&part=id,contentDetails", %{
      auth_type: :oauth2, access_token: token, plug: plug
    })
    |> format(:broadcast)
  end

  defp format({:ok, data}, :broadcast) do
    {:ok, %{
      broadcast_id: data["id"],
      title: get_in(data, ["snippet", "title"]),
      status: get_in(data, ["status", "lifeCycleStatus"]) || get_in(data, ["status", "recordingStatus"]),
      privacy: get_in(data, ["status", "privacyStatus"])
    }}
  end
  defp format(error, _), do: error

  defp to_s(p, k), do: p[k] || p[Atom.to_string(k)]
end
