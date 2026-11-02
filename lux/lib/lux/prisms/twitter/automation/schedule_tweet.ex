defmodule Lux.Prisms.Twitter.Automation.ScheduleTweet do
  @moduledoc """
  A prism for scheduling tweets and threads with priority levels and timestamps.
  """

  use Lux.Prism,
    name: "Schedule Tweet",
    description: "Schedules tweets or threads for future automated publication with priority handling",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Content of the tweet"},
        scheduled_at: %{type: :string, description: "ISO8601 publication timestamp"},
        priority: %{type: :string, description: "'high', 'normal', or 'low'"},
        media_ids: %{type: :array, description: "Optional media IDs"},
        thread_items: %{type: :array, description: "Optional subsequent thread tweets"}
      },
      required: ["text", "scheduled_at"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        text: %{type: :string},
        status: %{type: :string},
        scheduled_at: %{type: :string},
        priority: %{type: :string}
      },
      required: ["id", "status", "scheduled_at"]
    }

  alias Lux.Integrations.Twitter.Automation.Scheduler

  def handler(params, _agent) when is_map(params) do
    queue = Scheduler.new_queue()

    case Scheduler.schedule(queue, params) do
      {:ok, _updated_queue, item} ->
        {:ok,
         %{
           id: item.id,
           text: item.text,
           status: to_string(item.status),
           scheduled_at: DateTime.to_iso8601(item.scheduled_at),
           priority: to_string(item.priority)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid input: expected text and scheduled_at"}
end
