defmodule Lux.Prisms.Telegram.Analytics.MessageAnalytics do
  @moduledoc """
  A prism for recording and retrieving Telegram message analytics.

  This prism provides a unified interface for tracking message events and
  querying aggregate message statistics.

  ## Examples

      # Record a sent message
      iex> MessageAnalytics.handler(%{
      ...>   action: "record",
      ...>   direction: "sent",
      ...>   chat_id: 123_456_789,
      ...>   user_id: 42,
      ...>   message_type: "text"
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, event_type: :message_sent}}

      # Get message statistics
      iex> MessageAnalytics.handler(%{action: "stats"}, %{name: "Agent"})
      {:ok, %{total_sent: 10, total_received: 5, ...}}
  """

  use Lux.Prism,
    name: "Telegram Message Analytics",
    description: "Records and retrieves Telegram message analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'record' to log a message event, 'stats' to retrieve statistics",
          enum: ["record", "stats"]
        },
        direction: %{
          type: :string,
          description: "Message direction (required for 'record' action)",
          enum: ["sent", "received", "forwarded", "edited", "deleted"]
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Chat identifier (for 'record' action)"
        },
        user_id: %{
          type: [:string, :integer],
          description: "User identifier (for 'record' action)"
        },
        message_type: %{
          type: :string,
          description: "Type of message: text, photo, video, etc. (for 'record' action)"
        },
        from: %{
          type: :integer,
          description: "Start timestamp in milliseconds (for 'stats' with time range)"
        },
        to: %{
          type: :integer,
          description: "End timestamp in milliseconds (for 'stats' with time range)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recorded: %{type: :boolean, description: "Whether the event was recorded (record action)"},
        event_type: %{type: :string, description: "The event type recorded"},
        total_sent: %{type: :integer, description: "Total messages sent"},
        total_received: %{type: :integer, description: "Total messages received"},
        total_forwarded: %{type: :integer, description: "Total messages forwarded"},
        total_edited: %{type: :integer, description: "Total messages edited"},
        total_deleted: %{type: :integer, description: "Total messages deleted"},
        total: %{type: :integer, description: "Total message events"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles message analytics actions.
  """
  def handler(%{action: "record"} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    direction = params |> Map.get(:direction, "received") |> String.to_existing_atom()

    metadata =
      params
      |> Map.take([:chat_id, :user_id, :message_type])
      |> Map.put(:agent, agent_name)

    Logger.info("Agent #{agent_name} recording #{direction} message event")
    Analytics.record_message(direction, metadata)

    event_type = :"message_#{direction}"
    {:ok, %{recorded: true, event_type: event_type}}
  end

  def handler(%{action: "stats"} = params, _agent) do
    stats =
      case {params[:from], params[:to]} do
        {from, to} when is_integer(from) and is_integer(to) ->
          Analytics.get_message_stats(%{from: from, to: to})

        _ ->
          Analytics.get_message_stats()
      end

    {:ok, stats}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'record' or 'stats'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
