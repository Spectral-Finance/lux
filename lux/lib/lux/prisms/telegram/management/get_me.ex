defmodule Lux.Prisms.Telegram.Management.GetMe do
  @moduledoc """
  A prism for getting basic information about the bot via the Telegram Bot API.

  This prism provides a simple interface to call the getMe endpoint, which returns
  basic information about the bot such as its id, name, username, and capabilities.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /getMe
  - No required parameters
  - Returns bot info including id, first_name, username, can_join_groups, etc.

  ## Examples

      iex> GetMe.handler(%{}, %{name: "Agent"})
      {:ok, %{id: 123456789, is_bot: true, first_name: "MyBot", username: "my_bot"}}
  """

  use Lux.Prism,
    name: "Get Telegram Bot Info",
    description: "Returns basic information about the bot via the Telegram Bot API",
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
          description: "Unique identifier for this bot"
        },
        is_bot: %{
          type: :boolean,
          description: "True, this user is a bot"
        },
        first_name: %{
          type: :string,
          description: "Bot's first name"
        },
        username: %{
          type: :string,
          description: "Bot's username"
        },
        can_join_groups: %{
          type: :boolean,
          description: "True, if the bot can be invited to groups"
        },
        can_read_all_group_messages: %{
          type: :boolean,
          description: "True, if privacy mode is disabled for the bot"
        },
        supports_inline_queries: %{
          type: :boolean,
          description: "True, if the bot supports inline queries"
        }
      },
      required: ["id", "is_bot", "first_name"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Handles the request to get bot information.

  This implementation:
  - Makes a direct request to Telegram Bot API using the Client module
  - Returns bot info on success
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting bot info via getMe")

    request_opts = %{json: %{}}
    request_opts = maybe_add_plug(request_opts, params[:plug])

    case Client.request(:post, "/getMe", request_opts) do
      {:ok, %{"result" => result}} ->
        Logger.info("Successfully retrieved bot info")
        {:ok, %{
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

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Map.put(opts, :plug, plug)
end
