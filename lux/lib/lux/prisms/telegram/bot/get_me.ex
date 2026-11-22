defmodule Lux.Prisms.Telegram.Bot.GetMe do
  @moduledoc """
  A prism for retrieving the bot's own identity via the Telegram Bot API.

  This is the canonical way to verify that a bot token is valid (bot authentication
  and management) and to discover the bot's username, id and name.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: GET /getMe
  - Requires no parameters beyond the configured bot token
  - Returns the normalized bot profile on success
  - Preserves original Telegram API errors for better error handling by LLMs

  ## Examples

      GetMe.handler(%{}, %{name: "Agent"})
      #=> {:ok, %{id: 123_456_789, is_bot: true, first_name: "LuxBot", username: "lux_bot"}}

      # Invalid token
      GetMe.handler(%{}, %{name: "Agent"})
      #=> {:error, "Failed to get bot info: :invalid_token"}
  """

  use Lux.Prism,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot (authentication check) via the Telegram Bot API",
    input_schema: %{
      type: :object,
      properties: %{},
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :integer,
          description: "Unique identifier for the bot"
        },
        is_bot: %{
          type: :boolean,
          description: "True if the entity is a bot. Always true for getMe."
        },
        first_name: %{
          type: :string,
          description: "Bot's first name"
        },
        username: %{
          type: :string,
          description: "Bot's username, if set"
        },
        can_join_groups: %{
          type: :boolean,
          description: "True if the bot can be invited to groups"
        },
        can_read_all_group_messages: %{
          type: :boolean,
          description: "True if privacy mode is disabled for the bot"
        },
        supports_inline_queries: %{
          type: :boolean,
          description: "True if the bot supports inline queries"
        }
      },
      required: ["id", "is_bot", "first_name"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to fetch the bot's own profile.

  This implementation:
  - Makes a direct GET request to Telegram Bot API using the Client module
  - Returns the normalized bot profile on success
  - Logs the operation for monitoring purposes
  """
  def handler(_params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} fetching bot info (getMe)")

    case Client.request(:get, "/getMe") do
      {:ok, %{"result" => result}} when is_map(result) ->
        Logger.info("Successfully fetched bot info for #{result["username"] || result["id"]}")

        {:ok,
         %{
           id: result["id"],
           is_bot: result["is_bot"],
           first_name: result["first_name"],
           username: result["username"],
           can_join_groups: result["can_join_groups"],
           can_read_all_group_messages: result["can_read_all_group_messages"],
           supports_inline_queries: result["supports_inline_queries"]
         }}

      {:error, {status, %{"description" => description}}} ->
        {:error, "Failed to get bot info: #{description} (HTTP #{status})"}

      {:error, {status, description}} when is_binary(description) ->
        {:error, "Failed to get bot info: #{description} (HTTP #{status})"}

      {:error, error} ->
        {:error, "Failed to get bot info: #{inspect(error)}"}
    end
  end
end