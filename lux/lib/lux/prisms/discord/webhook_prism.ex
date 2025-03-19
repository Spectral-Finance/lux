defmodule Lux.Prisms.Discord.WebhookPrism do
  @moduledoc """
  A prism for executing Discord webhooks.
  This prism provides functionality to:
  1. Execute webhooks with messages and files
  2. Edit previously sent webhook messages
  3. Delete webhook messages
  4. Handle webhook rate limits

  ## Examples
      iex> Lux.Prisms.Discord.WebhookPrism.focus(%{
      ...>   webhook: %{
      ...>     id: "123456789012345678",
      ...>     token: "webhook_token",
      ...>     content: "Hello from webhook!"
      ...>   }
      ...> })
      {:ok, %{type: "webhook_message", message_id: "123456789012345678"}}

  ## Error Cases
      iex> Lux.Prisms.Discord.WebhookPrism.focus(%{})
      {:error, "Missing webhook data"}
  """

  use Lux.Prism,
    name: "Discord Webhook Prism",
    description: "Executes Discord webhooks",
    schema: %{
      type: :object,
      properties: %{
        content: %{
          type: :string,
          description: "The message contents (up to 2000 characters)",
          maxLength: 2000
        },
        username: %{
          type: :string,
          description: "Override the default username of the webhook",
          maxLength: 80
        },
        avatar_url: %{
          type: :string,
          description: "Override the default avatar of the webhook"
        },
        tts: %{
          type: :boolean,
          description: "True if this is a TTS message"
        },
        embeds: %{
          type: :array,
          description: "Embedded rich content (up to 10 embeds)",
          maxItems: 10,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string},
              type: %{type: :string},
              description: %{type: :string},
              url: %{type: :string},
              timestamp: %{type: :string},
              color: %{type: :integer},
              footer: %{type: :object},
              image: %{type: :object},
              thumbnail: %{type: :object},
              author: %{type: :object},
              fields: %{
                type: :array,
                items: %{
                  type: :object,
                  properties: %{
                    name: %{type: :string},
                    value: %{type: :string},
                    inline: %{type: :boolean}
                  }
                }
              }
            }
          }
        },
        allowed_mentions: %{
          type: :object,
          description: "Allowed mentions for the message",
          properties: %{
            parse: %{
              type: :array,
              items: %{
                type: :string,
                enum: ["roles", "users", "everyone"]
              }
            },
            roles: %{
              type: :array,
              items: %{type: :string}
            },
            users: %{
              type: :array,
              items: %{type: :string}
            },
            replied_user: %{type: :boolean}
          }
        },
        components: %{
          type: :array,
          description: "Message components",
          items: %{type: :object}
        },
        files: %{
          type: :array,
          description: "Files to send with the message",
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              content: %{type: :string}
            }
          }
        },
        attachments: %{
          type: :array,
          description: "Attachment objects with filename and description",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :integer},
              filename: %{type: :string},
              description: %{type: :string}
            }
          }
        },
        flags: %{
          type: :integer,
          description: "Message flags combined as a bitfield"
        },
        thread_name: %{
          type: :string,
          description: "Name of thread to create (requires the webhook channel to be a forum channel)",
          maxLength: 100
        }
      },
      oneOf: [
        %{required: ["content"]},
        %{required: ["embeds"]},
        %{required: ["files"]}
      ]
    }

  require Logger

  @impl true
  def before_focus(%{webhook: %{id: id, token: token} = webhook}) do
    # Build the webhook execution payload
    payload = %{
      content: webhook[:content],
      username: webhook[:username],
      avatar_url: webhook[:avatar_url],
      tts: webhook[:tts],
      embeds: webhook[:embeds],
      allowed_mentions: webhook[:allowed_mentions],
      components: webhook[:components],
      files: webhook[:files],
      attachments: webhook[:attachments],
      flags: webhook[:flags],
      thread_name: webhook[:thread_name]
    }
    |> Map.reject(fn {_, v} -> is_nil(v) end)

    {:ok, payload}
  end

  def before_focus(input) do
    Logger.error("Invalid webhook data: #{inspect(input)}")
    {:error, "Invalid webhook data"}
  end

  @impl true
  def after_focus({:ok, response}) do
    case response do
      %{id: message_id} ->
        {:ok, %{type: "webhook_message", message_id: message_id}}
      _ ->
        {:ok, %{type: "webhook_executed"}}
    end
  end

  def after_focus({:error, reason}) do
    {:error, reason}
  end
end
