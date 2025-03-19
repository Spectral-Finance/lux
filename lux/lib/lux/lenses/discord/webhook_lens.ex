defmodule Lux.Lenses.Discord.WebhookLens do
  @moduledoc """
  A lens for reading Discord webhooks.
  This lens provides functionality to:
  1. Parse and validate webhook data
  2. Handle different types of webhooks (Incoming, Channel Follower, Application)
  3. Process webhook message content and embeds

  ## Examples
      iex> Lux.Lenses.Discord.WebhookLens.focus(%{
      ...>   type: 1,
      ...>   id: "123456789012345678",
      ...>   name: "test webhook"
      ...> })
      {:ok, %{webhook: %{type: "INCOMING", name: "test webhook"}}}

  ## Error Cases
      iex> Lux.Lenses.Discord.WebhookLens.focus(%{type: 99})
      {:error, "Invalid webhook type: 99"}
  """

  use Lux.Lens,
    name: "Discord Webhook Lens",
    description: "Reads Discord webhook data",
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The id of the webhook",
          pattern: "^[0-9]{17,20}$"
        },
        type: %{
          type: :integer,
          description: "The type of the webhook",
          enum: [1, 2, 3],
          mapping: %{
            1 => "INCOMING",
            2 => "CHANNEL_FOLLOWER",
            3 => "APPLICATION"
          }
        },
        guild_id: %{
          type: :string,
          description: "The guild id this webhook is for",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "The channel id this webhook is for",
          pattern: "^[0-9]{17,20}$"
        },
        user: %{
          type: :object,
          description: "The user this webhook was created by",
          properties: %{
            id: %{type: :string},
            username: %{type: :string},
            discriminator: %{type: :string},
            avatar: %{type: [:string, :null]}
          }
        },
        name: %{
          type: :string,
          description: "The default name of the webhook",
          minLength: 1,
          maxLength: 80
        },
        avatar: %{
          type: [:string, :null],
          description: "The default avatar of the webhook"
        },
        token: %{
          type: :string,
          description: "The secure token of the webhook (returned for Incoming Webhooks)"
        },
        application_id: %{
          type: [:string, :null],
          description: "The bot/OAuth2 application that created this webhook",
          pattern: "^[0-9]{17,20}$"
        },
        source_guild: %{
          type: :object,
          description: "The guild of the channel that is being followed (returned for Channel Follower Webhooks)",
          properties: %{
            id: %{type: :string},
            name: %{type: :string},
            icon: %{type: [:string, :null]}
          }
        },
        source_channel: %{
          type: :object,
          description: "The channel that is being followed (returned for Channel Follower Webhooks)",
          properties: %{
            id: %{type: :string},
            name: %{type: :string}
          }
        },
        url: %{
          type: :string,
          description: "The url used for executing the webhook"
        }
      },
      required: ["id", "type"]
    }

  require Logger

  @impl true
  def after_focus(%{type: type} = input) when type in [1, 2, 3] do
    webhook_type = case type do
      1 -> "INCOMING"
      2 -> "CHANNEL_FOLLOWER"
      3 -> "APPLICATION"
    end

    processed = %{
      webhook: %{
        id: input.id,
        type: webhook_type,
        guild_id: input[:guild_id],
        channel_id: input[:channel_id],
        name: input[:name],
        avatar: input[:avatar],
        token: input[:token],
        application_id: input[:application_id],
        user: input[:user],
        source_guild: input[:source_guild],
        source_channel: input[:source_channel],
        url: input[:url]
      }
    }

    {:ok, processed}
  end

  def after_focus(%{type: type}) do
    {:error, "Invalid webhook type: #{type}"}
  end

  def after_focus(input) do
    Logger.error("Invalid input format: #{inspect(input)}")
    {:error, "Invalid input format"}
  end
end
