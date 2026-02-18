defmodule Lux.Prisms.Telegram.Analytics.UserEngagement do
  @moduledoc """
  A prism for tracking and analyzing Telegram user engagement.

  Provides tools for recording user interactions and querying engagement
  metrics including active user counts, interaction frequency, and top users.

  ## Examples

      # Track a user interaction
      iex> UserEngagement.handler(%{
      ...>   action: "track",
      ...>   user_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{tracked: true, user_id: 42}}

      # Get engagement statistics
      iex> UserEngagement.handler(%{action: "stats"}, %{name: "Agent"})
      {:ok, %{total_unique_users: 15, active_users_last_hour: 3, ...}}
  """

  use Lux.Prism,
    name: "Telegram User Engagement",
    description: "Tracks and analyzes Telegram user engagement metrics",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Action to perform: 'track' to log user activity, 'stats' to retrieve engagement data",
          enum: ["track", "stats"]
        },
        user_id: %{
          type: [:string, :integer],
          description: "User identifier (required for 'track' action)"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tracked: %{type: :boolean, description: "Whether the activity was tracked"},
        user_id: %{type: [:string, :integer], description: "The tracked user ID"},
        total_unique_users: %{type: :integer, description: "Total unique users"},
        active_users_last_hour: %{type: :integer, description: "Users active in the last hour"},
        active_users_last_day: %{type: :integer, description: "Users active in the last 24 hours"},
        top_users: %{type: :array, description: "Top users by message count"}
      }
    }

  alias Lux.Integrations.Telegram.Analytics
  require Logger

  @doc """
  Handles user engagement tracking and querying.
  """
  def handler(%{action: "track"} = params, agent) do
    case Map.fetch(params, :user_id) do
      {:ok, user_id} when not is_nil(user_id) ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} tracking activity for user #{user_id}")
        Analytics.track_user_activity(user_id)
        {:ok, %{tracked: true, user_id: user_id}}

      _ ->
        {:error, "Missing required parameter: user_id"}
    end
  end

  def handler(%{action: "stats"}, _agent) do
    {:ok, Analytics.get_user_engagement()}
  end

  def handler(%{action: action}, _agent) do
    {:error, "Unknown action: #{action}. Use 'track' or 'stats'."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: action"}
  end
end
