defmodule Lux.Prisms.Discord.Webhooks.ListWebhooks do
  @moduledoc """
  A prism for listing Discord channel webhooks.

  Retrieves all webhooks for a given channel or guild.

  ## Examples

      iex> ListWebhooks.handler(%{channel_id: "123456789"}, %{name: "Agent"})
      {:ok, %{webhooks: [...], count: 2}}

  """

  use Lux.Prism,
    name: "List Discord Webhooks",
    description: "Lists webhooks for a Discord channel or guild",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel ID to list webhooks for"},
        guild_id: %{type: :string, description: "Guild ID (alternative to channel_id)"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        webhooks: %{type: :array, description: "Webhook objects"},
        count: %{type: :integer, description: "Number of webhooks"}
      },
      required: ["webhooks"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"

    {path, log_msg} =
      cond do
        channel_id = Map.get(params, :channel_id) ->
          {"/channels/#{channel_id}/webhooks", "channel #{channel_id}"}

        guild_id = Map.get(params, :guild_id) ->
          {"/guilds/#{guild_id}/webhooks", "guild #{guild_id}"}

        true ->
          {nil, nil}
      end

    if path do
      Logger.info("Agent #{agent_name} listing webhooks for #{log_msg}")

      case Client.request(:get, path, Map.drop(params, [:channel_id, :guild_id])) do
        {:ok, webhooks} when is_list(webhooks) ->
          Logger.info("Found #{length(webhooks)} webhooks for #{log_msg}")
          {:ok, %{webhooks: webhooks, count: length(webhooks)}}

        {:ok, other} ->
          {:error, {:unexpected_response, other}}

        {:error, error} ->
          Logger.error("Failed to list webhooks for #{log_msg}: #{inspect(error)}")
          {:error, error}
      end
    else
      {:error, "Missing channel_id or guild_id"}
    end
  end
end
