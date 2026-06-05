defmodule Lux.Prisms.YouTube.Live.ManageBroadcast do
  @moduledoc """
  Builds a YouTube Core and Live Streaming workflow plan for Lux agents.

  The prism intentionally defaults to dry-run planning. It returns the YouTube
  Data API request envelopes an adapter would execute after OAuth credentials
  and channel review are available.
  """

  use Lux.Prism,
    name: "Manage YouTube Live Broadcast",
    description: "Plans YouTube Data API v3 upload, live broadcast, live chat, health, and transition workflows",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string, description: "Broadcast title"},
        scheduled_start_time: %{type: :string, description: "RFC3339 scheduled start time"},
        description: %{type: :string, description: "Broadcast description"},
        privacy_status: %{type: :string, enum: ["private", "unlisted", "public"]},
        stream_id: %{type: :string, description: "Existing YouTube live stream ID"},
        broadcast_id: %{type: :string, description: "Existing YouTube live broadcast ID"},
        live_chat_id: %{type: :string, description: "Live chat ID for chat monitoring"},
        target_life_cycle_status: %{type: :string, enum: ["testing", "live", "complete"]},
        chat_message: %{type: :string, description: "Optional chat message draft"},
        dry_run: %{type: :boolean, description: "Return a plan without executing live YouTube calls"}
      },
      required: ["title", "scheduled_start_time"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        planned: %{type: :boolean},
        mode: %{type: :string},
        workflow: %{type: :object},
        execution_boundary: %{type: :object}
      },
      required: ["planned", "mode", "workflow"]
    }

  alias Lux.Integrations.YouTube.LiveStreaming

  @doc """
  Returns a deterministic YouTube live workflow plan.
  """
  def handler(params, _agent) do
    case LiveStreaming.plan_broadcast_workflow(params) do
      {:ok, workflow} ->
        {:ok,
         %{
           planned: true,
           mode: "dry_run",
           workflow: workflow,
           execution_boundary: workflow.execution_boundary
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
