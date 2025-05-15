defmodule Lux.Prisms.Discord.Channels.EditChannel do
  @moduledoc """
  A prism for modifying Discord channel settings.

  This prism provides a simple interface for editing Discord channels with:
  - Required parameters (channel_id)
  - Optional parameters (name, topic, nsfw)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> EditChannel.handler(%{
      ...>   channel_id: "123456789012345678",
      ...>   name: "new-channel-name",
      ...>   topic: "New channel topic"
      ...> }, %{name: "Agent"})
      {:ok, %{
        edited: true,
        channel_id: "123456789012345678",
        name: "new-channel-name",
        topic: "New channel topic"
      }}
  """

  use Lux.Prism,
    name: "Edit Discord Channel",
    description: "Modifies Discord channel settings",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to edit",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "New name of the channel",
          minLength: 1,
          maxLength: 100
        },
        topic: %{
          type: :string,
          description: "New topic of the channel",
          maxLength: 1024
        },
        nsfw: %{
          type: :boolean,
          description: "Whether the channel is NSFW"
        }
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{
          type: :boolean,
          description: "Whether the channel was successfully edited"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the edited channel"
        },
        name: %{
          type: :string,
          description: "Updated channel name"
        },
        topic: %{
          type: :string,
          description: "Updated channel topic"
        }
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to edit a Discord channel.

  Returns {:ok, %{edited: true, channel_id: id, name: name, topic: topic}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_channel_id(params),
         {:ok, request_body} <- build_request_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} editing channel #{channel_id}")

      case Client.request(:patch, "/channels/#{channel_id}", %{json: request_body}) do
        {:ok, response} ->
          Logger.info("Successfully edited channel #{channel_id}")
          {:ok, %{
            edited: true,
            channel_id: response["id"],
            name: response["name"],
            topic: response["topic"]
          }}
        error ->
          Logger.error("Failed to edit channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_channel_id(params) do
    case Map.fetch(params, :channel_id) do
      {:ok, channel_id} when is_binary(channel_id) ->
        if Regex.match?(~r/^\d{17,20}$/, channel_id) do
          {:ok, channel_id}
        else
          {:error, "Missing or invalid channel_id"}
        end
      _ ->
        {:error, "Missing or invalid channel_id"}
    end
  end

  defp build_request_body(params) do
    body = params
    |> Map.take([:name, :topic, :nsfw])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, body}
  end
end
