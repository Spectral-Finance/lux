defmodule Lux.Prisms.Telegram.Analytics.CommandUsage do
  @moduledoc """
  A prism for tracking and analyzing Telegram bot command usage.

  Records command executions with timing data and provides aggregate
  statistics including per-command counts, success rates, and most-used commands.

  ## Examples

      # Record a command execution
      iex> CommandUsage.handler(%{
      ...>   action: "record",
      ...>   command: "start",
      ...>   user_id: 42,
      ...>   response_time_ms: 150,
      ...>   success: true
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, command: "start"}}

      # Get command usage statistics
      iex> CommandUsage.handler(%{action: "stats"}, %{name: "Agent"})
      {:ok, %{commands: %{"start" => %{count: 42, ...}}, total_commands: 57, most_used: "start"}}
  """

  use Lux.Prism,
    name: "Telegram Command Usage",
    description: "Tracks and analyzes Telegram bot command usage statistics",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'record' to log a command, 'stats' to retrieve statistics",
          enum: ["record", "stats"]
        },
        command: %{
          type: :string,
          description: "Command name without leading slash (required for 'record' action)"
        },
        user_id: %{
          type: [:string, :integer],
          description: "User who executed the command"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Chat where the command was executed"
        },
        response_time_ms: %{
          type: :number,
          description: "Response time in milliseconds"
        },
        success: %{
          type: :boolean,
          description: "Whether the command executed successfully (default: true)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recorded: %{type: :boolean, description: "Whether the command was recorded"},
        command: %{type: :string, description: "The recorded command name"},
        commands: %{type: :object, description: "Per-command statistics"},
        total_commands: %{type: :integer, description: "Total command executions"},
        most_used: %{type: :string, description: "Most frequently used command"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles command usage recording and statistics retrieval.
  """
  def handler(%{action: "record"} = params, agent) do
    case Map.fetch(params, :command) do
      {:ok, command} when is_binary(command) and command != "" ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} recording command /#{command}")

        metadata =
          params
          |> Map.take([:user_id, :chat_id, :response_time_ms, :success])
          |> Map.put(:agent, agent_name)

        Analytics.record_command(command, metadata)
        {:ok, %{recorded: true, command: command}}

      _ ->
        {:error, "Missing or invalid command parameter"}
    end
  end

  def handler(%{action: "stats"}, _agent) do
    {:ok, Analytics.get_command_stats()}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'record' or 'stats'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
