defmodule Lux.Prisms.Discord.Webhook.ExecuteWebhook do
  @moduledoc """
  A prism for executing a Discord webhook with full message formatting support.

  Supports embeds, components, files, username/avatar override, thread support,
  and wait/response handling.
  """

  use Lux.Prism,
    name: "Execute Discord Webhook",
    description: "Executes a Discord webhook with rich message formatting",
    input_schema: %{
      type: :object,
      properties: %{
        webhook_id: %{
          type: :string,
          description: "The webhook ID",
          pattern: "^[0-9]{17,20}$"
        },
        token: %{
          type: :string,
          description: "The webhook token"
        },
        content: %{
          type: :string,
          description: "Message content (max 2000 chars)",
          maxLength: 2000
        },
        username: %{
          type: :string,
          description: "Override default username (max 80 chars)",
          maxLength: 80
        },
        avatar_url: %{
          type: :string,
          description: "Override default avatar URL",
          format: "uri"
        },
        tts: %{
          type: :boolean,
          description: "Text-to-speech",
          default: false
        },
        embeds: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string, maxLength: 256},
              description: %{type: :string, maxLength: 4096},
              url: %{type: :string, format: "uri"},
              color: %{type: :integer, minimum: 0, maximum: 16777215},
              timestamp: %{type: :string, format: "date-time"},
              footer: %{
                type: :object,
                properties: %{
                  text: %{type: :string, maxLength: 2048},
                  icon_url: %{type: :string, format: "uri"}
                }
              },
              author: %{
                type: :object,
                properties: %{
                  name: %{type: :string, maxLength: 256},
                  url: %{type: :string, format: "uri"},
                  icon_url: %{type: :string, format: "uri"}
                }
              },
              fields: %{
                type: :array,
                items: %{
                  type: :object,
                  properties: %{
                    name: %{type: :string, maxLength: 256},
                    value: %{type: :string, maxLength: 1024},
                    inline: %{type: :boolean}
                  },
                  required: ["name", "value"]
                },
                maxItems: 25
              },
              image: %{
                type: :object,
                properties: %{
                  url: %{type: :string, format: "uri"}
                }
              },
              thumbnail: %{
                type: :object,
                properties: %{
                  url: %{type: :string, format: "uri"}
                }
              }
            }
          },
          maxItems: 10
        },
        components: %{
          type: :array,
          description: "Message components (buttons, select menus)",
          items: %{type: :object}
        },
        allowed_mentions: %{
          type: :object,
          properties: %{
            parse: %{type: :array, items: %{type: :string, enum: ["roles", "users", "everyone"]}},
            roles: %{type: :array, items: %{type: :string}},
            users: %{type: :array, items: %{type: :string}},
            replied_user: %{type: :boolean}
          }
        },
        thread_id: %{
          type: :string,
          description: "Thread ID to send message in",
          pattern: "^[0-9]{17,20}$"
        },
        wait: %{
          type: :boolean,
          description: "Wait for server confirmation and return message",
          default: false
        }
      },
      required: ["webhook_id", "token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{
          type: :boolean,
          description: "Whether message was successfully sent"
        },
        message_id: %{
          type: :string,
          description: "ID of the sent message (if wait=true)"
        },
        channel_id: %{
          type: :string,
          description: "Channel ID where message was sent"
        }
      },
      required: ["sent"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @max_retries 3
  @retry_delay_ms 500

  @doc """
  Executes a webhook with retry logic for rate limits.

  Returns {:ok, %{sent: true, message_id: id, channel_id: id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, webhook_id} <- Helpers.validate_string(params, "webhook_id"),
         {:ok, token} <- Helpers.validate_string(params, "token"),
         {:ok, content} <- Helpers.validate_string(params, "content", nil),
         {:ok, username} <- Helpers.validate_string(params, "username", nil),
         {:ok, avatar_url} <- Helpers.validate_string(params, "avatar_url", nil),
         {:ok, tts} <- Helpers.validate_boolean(params, "tts", false),
         {:ok, embeds} <- Helpers.validate_list(params, "embeds", []),
         {:ok, components} <- Helpers.validate_list(params, "components", []),
         {:ok, allowed_mentions} <- Helpers.optional(params, "allowed_mentions"),
         {:ok, thread_id} <- Helpers.validate_string(params, "thread_id", nil),
         {:ok, wait} <- Helpers.validate_boolean(params, "wait", false) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} executing webhook #{webhook_id}")

      body = %{
        "content" => content,
        "username" => username,
        "avatar_url" => avatar_url,
        "tts" => tts,
        "embeds" => embeds,
        "components" => components,
        "allowed_mentions" => allowed_mentions
      }
      |> Enum.filter(fn {_, v} -> v != nil and v != [] end)
      |> Enum.into(%{})

      query_params = if wait, do: "?wait=true", else: ""
      thread_param = if thread_id, do: "&thread_id=#{thread_id}", else: ""
      path = "/webhooks/#{webhook_id}/#{token}#{query_params}#{thread_param}"

      execute_with_retry(path, body, 0)
    end
  end

  defp execute_with_retry(path, body, attempt) do
    case Client.request(:post, path, %{json: body}) do
      {:ok, %{"id" => message_id, "channel_id" => channel_id}} ->
        {:ok, %{sent: true, message_id: message_id, channel_id: channel_id}}

      {:ok, _} ->
        {:ok, %{sent: true}}

      {:error, {429, %{"retry_after" => retry_after}}} when attempt < @max_retries ->
        Logger.warning("Rate limited, waiting #{retry_after}ms before retry #{attempt + 1}")
        Process.sleep(retry_after)
        execute_with_retry(path, body, attempt + 1)

      {:error, {429, _}} when attempt < @max_retries ->
        delay = @retry_delay_ms * :math.pow(2, attempt) |> trunc()
        Logger.warning("Rate limited, exponential backoff #{delay}ms before retry #{attempt + 1}")
        Process.sleep(delay)
        execute_with_retry(path, body, attempt + 1)

      {:error, {status, _}} = error when status >= 500 and status < 600 and attempt < @max_retries ->
        delay = @retry_delay_ms * :math.pow(2, attempt) |> trunc()
        Logger.warning("Server error #{status}, retry #{attempt + 1} after #{delay}ms")
        Process.sleep(delay)
        execute_with_retry(path, body, attempt + 1)

      {:error, {status, %{"message" => message}}} ->
        {:error, {status, message}}

      {:error, error} ->
        {:error, error}
    end
  end
end