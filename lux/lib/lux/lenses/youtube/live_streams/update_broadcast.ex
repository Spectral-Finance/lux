defmodule Lux.Lenses.YouTube.LiveStreams.UpdateBroadcast do
  @moduledoc """
  A lens for updating broadcast feed parameters on YouTube.

  Allows modifying broadcast settings such as:
  - Latency policy (low, balanced, standard)
  - Retention policy (keep, delete)
  - Ad break configuration
  - Chat enablement
  - Recording settings
  - Friendly name

  ## Parameters

  - `broadcast_id`: YouTube broadcast ID (required)
  - `latency_policy`: Stream latency setting
  - `retention_policy`: Post-stream content retention
  - `enable_chat`: Enable/disable live chat
  - `enable_ads`: Enable/disable ad breaks
  - `ad_break_wait_time`: Time between ad breaks (seconds)
  - `record_from_start`: Record stream from start
  - `friendly_name`: Custom broadcast name

  ## Examples

      iex> UpdateBroadcast.focus(%{
      ...>   broadcast_id: "abc123...",
      ...>   latency_policy: %{policy: "lowLatency"},
      ...>   enable_chat: true
      ...> })
      {:ok, %{id: "abc123...", ...}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Update YouTube Broadcast",
    description: "Updates broadcast feed parameters for a YouTube live stream",
    url: "#{YouTube.api_base_url()}/liveBroadcasts",
    method: :patch,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "YouTube broadcast ID to update",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        part: %{
          type: :string,
          description: "Resource parts to update",
          default: "snippet,status,contentDetails"
        },
        title: %{
          type: :string,
          description: "New broadcast title"
        },
        description: %{
          type: :string,
          description: "New broadcast description"
        },
        scheduled_start_time: %{
          type: :string,
          description: "New scheduled start time (ISO 8601)"
        },
        scheduled_end_time: %{
          type: :string,
          description: "New scheduled end time (ISO 8601)"
        },
        latency_policy: %{
          type: :object,
          description: "Stream latency policy configuration",
          properties: %{
            policy: %{
              type: :string,
              enum: ["lowLatency", "balancedLatency", "standardLatency"]
            }
          }
        },
        retention_policy: %{
          type: :object,
          description: "Post-stream content retention policy",
          properties: %{
            keep_vod: %{
              type: :boolean,
              description: "Keep the video on demand after stream ends",
              default: true
            },
            keep_live: %{
              type: :boolean,
              description: "Keep the live broadcast resource",
              default: true
            }
          }
        },
        enable_chat: %{
          type: :boolean,
          description: "Enable or disable live chat for this broadcast",
          default: true
        },
        enable_ads: %{
          type: :boolean,
          description: "Enable ad breaks for this broadcast",
          default: false
        },
        ad_break_wait_time: %{
          type: :integer,
          description: "Time between ad breaks in seconds (15-600)",
          minimum: 15,
          maximum: 600
        },
        record_from_start: %{
          type: :boolean,
          description: "Record the stream from its start time"
        },
        friendly_name: %{
          type: :string,
          description: "Custom friendly name for the broadcast"
        }
      },
      required: ["broadcast_id"]
    }

  @impl true
  def before_focus(params) do
    broadcast_id = params[:broadcast_id]
    part = Map.get(params, :part, "snippet,status,contentDetails")

    body = build_body(params)

    %{
      url: "#{YouTube.api_base_url()}/liveBroadcasts?id=#{broadcast_id}&part=#{part}",
      json: body
    }
  end

  @doc """
  Transforms the broadcast update response.
  """
  @impl true
  def after_focus(%{
    "id" => broadcast_id,
    "snippet" => snippet,
    "status" => status,
    "contentDetails" => content_details
  }) do
    Logger.info("Successfully updated broadcast: #{broadcast_id}")

    {:ok, %{
      id: broadcast_id,
      title: snippet["title"],
      scheduled_start_time: snippet["scheduledStartTime"],
      scheduled_end_time: snippet["scheduledEndTime"],
      life_cycle_status: Map.get(status, "lifeCycleStatus"),
      latency_policy: Map.get(content_details, "latencyPolicy"),
      retention_policy: Map.get(content_details, "retentionPolicy"),
      enable_chat: Map.get(content_details, "enableChat"),
      friendly_name: Map.get(content_details, "friendlyName")
    }}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_body(params) do
    snippet = build_snippet(params)
    status = build_status(params)
    content_details = build_content_details(params)

    %{
      snippet: snippet,
      status: status,
      contentDetails: content_details
    }
  end

  defp build_snippet(params) do
    snippet = %{}
    snippet = maybe_put(snippet, :title, Map.get(params, :title))
    snippet = maybe_put(snippet, :description, Map.get(params, :description))
    snippet = maybe_put(snippet, :scheduledStartTime, Map.get(params, :scheduled_start_time))
    snippet = maybe_put(snippet, :scheduledEndTime, Map.get(params, :scheduled_end_time))
    snippet
  end

  defp build_status(params) do
    status = %{}
    status = maybe_put(status, :communicationWithChattersAllowed, Map.get(params, :enable_chat))
    status
  end

  defp build_content_details(params) do
    content_details = %{}

    content_details =
      case Map.get(params, :latency_policy) do
        nil -> content_details
        %{policy: policy} -> Map.put(content_details, :latencyPolicy, %{policy: policy})
      end

    content_details =
      case Map.get(params, :retention_policy) do
        nil -> content_details
        retention ->
          Map.put(content_details, :retentionPolicy, %{
            keepVod: Map.get(retention, :keep_vod, true),
            keepLive: Map.get(retention, :keep_live, true)
          })
      end

    content_details = maybe_put(content_details, :enableChat, Map.get(params, :enable_chat))
    content_details = maybe_put(content_details, :enableAds, Map.get(params, :enable_ads))
    content_details = maybe_put(content_details, :adBreakWaitTime, Map.get(params, :ad_break_wait_time))
    content_details = maybe_put(content_details, :recordFromStart, Map.get(params, :record_from_start))
    content_details = maybe_put(content_details, :friendlyName, Map.get(params, :friendly_name))
    content_details
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
