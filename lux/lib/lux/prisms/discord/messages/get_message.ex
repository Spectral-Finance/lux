defmodule Lux.Prisms.Discord.Messages.GetMessage do
  @moduledoc """
  A prism for retrieving a single Discord message by ID.
  """

  use Lux.Prism,
    name: "Get Discord Message",
    description: "Retrieves a single message from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        message_id: %{type: :string, pattern: "^[0-9]{17,20}$"}
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object},
        channel_id: %{type: :string},
        message_id: %{type: :string}
      },
      required: ["message", "channel_id", "message_id"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Retrieves a single message from a Discord channel.

  Returns {:ok, %{message: ..., channel_id: ..., message_id: ...}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, message_id} <- Helpers.validate_string(params, :message_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching message #{message_id} from channel #{channel_id}")

      opts = Helpers.client_opts(params)

      case Client.request_with_retry(:get, "/channels/#{channel_id}/messages/#{message_id}", opts) do
        {:ok, message} ->
          {:ok, %{message: message, channel_id: channel_id, message_id: message_id}}

        error ->
          Logger.error("Failed to fetch message #{message_id} from #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end
end