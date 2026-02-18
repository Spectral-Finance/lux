defmodule Lux.Prisms.Telegram.Analytics.ErrorMonitoring do
  @moduledoc """
  A prism for monitoring and analyzing Telegram bot errors.

  Records error events with categorization and provides aggregate
  error statistics including error rates, error breakdowns by type,
  and recent error listings.

  ## Examples

      # Record an error
      iex> ErrorMonitoring.handler(%{
      ...>   action: "record",
      ...>   error_type: "api_error",
      ...>   message: "Rate limit exceeded",
      ...>   chat_id: 123_456_789
      ...> }, %{name: "Agent"})
      {:ok, %{recorded: true, error_type: "api_error"}}

      # Get error statistics
      iex> ErrorMonitoring.handler(%{action: "stats"}, %{name: "Agent"})
      {:ok, %{total_errors: 5, error_rate: 2.5, errors_by_type: %{...}}}
  """

  use Lux.Prism,
    name: "Telegram Error Monitoring",
    description: "Monitors and analyzes Telegram bot errors and failure rates",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'record' to log an error, 'stats' to retrieve error statistics",
          enum: ["record", "stats"]
        },
        error_type: %{
          type: :string,
          description: "Error category (required for 'record' action)",
          enum: ["api_error", "timeout", "validation", "auth", "rate_limit", "network", "internal", "unknown"]
        },
        message: %{
          type: :string,
          description: "Error message description"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Related chat identifier"
        },
        user_id: %{
          type: [:string, :integer],
          description: "Related user identifier"
        },
        operation: %{
          type: :string,
          description: "The operation that caused the error"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recorded: %{type: :boolean, description: "Whether the error was recorded"},
        error_type: %{type: :string, description: "The recorded error type"},
        total_errors: %{type: :integer, description: "Total error count"},
        errors_by_type: %{type: :object, description: "Errors grouped by type"},
        error_rate: %{type: :number, description: "Error rate as percentage"},
        recent_errors: %{type: :array, description: "Recent error events"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles error monitoring recording and statistics retrieval.
  """
  def handler(%{action: "record"} = params, agent) do
    case Map.fetch(params, :error_type) do
      {:ok, error_type} when is_binary(error_type) and error_type != "" ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} recording error: #{error_type}")

        metadata =
          params
          |> Map.take([:message, :chat_id, :user_id, :operation])
          |> Map.put(:agent, agent_name)

        Analytics.record_error(error_type, metadata)
        {:ok, %{recorded: true, error_type: error_type}}

      _ ->
        {:error, "Missing or invalid error_type parameter"}
    end
  end

  def handler(%{action: "stats"}, _agent) do
    {:ok, Analytics.get_error_stats()}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'record' or 'stats'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
