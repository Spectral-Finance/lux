defmodule Lux.Prisms.Discord.MessagePrism do
  @moduledoc """
  A prism for sending messages to Discord channels.

  ## Authentication

  Requires a Discord bot token in the application configuration:
  ```elixir
  config :lux, :discord_token, "your-bot-token"
  ```

  ## Rate Limiting

  Discord API has rate limits per route. This prism handles rate limiting by:
  - Respecting the retry_after header
  - Following the global rate limit
  - Using proper request headers

  ## Example

      iex> Lux.Prisms.Discord.MessagePrism.run(%{
      ...>   channel_id: "123456789",
      ...>   content: "Hello from Lux!",
      ...>   embeds: [
      ...>     %{
      ...>       title: "Example Embed",
      ...>       description: "This is a test embed",
      ...>       color: 0x7289DA
      ...>     }
      ...>   ]
      ...> })
      {:ok,
       %{
         status: "success",
         message: %{
           id: "987654321",
           channel_id: "123456789",
           content: "Hello from Lux!",
           timestamp: "2024-03-08T12:34:56Z"
         }
       }}

  ## Error Cases

      # Invalid channel ID
      iex> Lux.Prisms.Discord.MessagePrism.run(%{channel_id: "invalid"})
      {:error, %{type: "validation_error", message: "Invalid channel ID format"}}

      # Missing permissions
      iex> Lux.Prisms.Discord.MessagePrism.run(%{channel_id: "123456789"})
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}

      # Rate limited
      iex> Lux.Prisms.Discord.MessagePrism.run(%{channel_id: "123456789"})
      {:error, %{type: "rate_limit", retry_after: 5000}}

  The prism reads Discord authentication details from configuration:
  - :discord_token - Discord bot token for authentication
  """

  use Lux.Prism,
    name: "Discord Message Sender",
    description: "Sends messages to Discord channels",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    },
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Discord channel ID to send message to",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "Message content to send",
          maxLength: 2000
        },
        embeds: %{
          type: :array,
          description: "Optional rich embeds to include with the message",
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string, maxLength: 256},
              description: %{type: :string, maxLength: 4096},
              url: %{type: :string, format: "uri"},
              color: %{type: :integer},
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
                }
              }
            }
          },
          default: []
        }
      },
      required: ["channel_id", "content"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        message: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            channel_id: %{type: :string},
            content: %{type: :string},
            timestamp: %{type: :string, format: "date-time"}
          },
          required: ["id", "channel_id", "content", "timestamp"]
        }
      },
      required: ["status", "message"]
    }

  require Logger

  @doc """
  Adds Discord bot token to request headers.
  """
  def add_auth_header(prism) do
    token = Application.fetch_env!(:lux, :discord_token)
    %{prism | headers: prism.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  @doc """
  Validates the channel ID format.
  """
  defp validate_channel_id(channel_id) do
    if Regex.match?(~r/^[0-9]{17,20}$/, channel_id) do
      {:ok, channel_id}
    else
      {:error, %{
        type: "validation_error",
        message: "Invalid channel ID format",
        details: %{
          field: "channel_id",
          pattern: "^[0-9]{17,20}$",
          value: channel_id
        }
      }}
    end
  end

  @doc """
  Validates the message content.
  """
  defp validate_content(content) when is_binary(content) do
    cond do
      String.length(content) == 0 ->
        {:error, %{
          type: "validation_error",
          message: "Content cannot be empty",
          details: %{field: "content"}
        }}
      String.length(content) > 2000 ->
        {:error, %{
          type: "validation_error",
          message: "Content exceeds maximum length of 2000 characters",
          details: %{
            field: "content",
            max_length: 2000,
            actual_length: String.length(content)
          }
        }}
      true ->
        {:ok, content}
    end
  end

  defp validate_content(_) do
    {:error, %{
      type: "validation_error",
      message: "Content must be a string",
      details: %{field: "content"}
    }}
  end

  @doc """
  Prepares the request URL and body after validating inputs.
  """
  def before_handler(params) do
    with {:ok, channel_id} <- validate_channel_id(params.channel_id),
         {:ok, _content} <- validate_content(params.content) do
      # Extract channel_id and update URL
      url = String.replace(prism_url(), ":channel_id", channel_id)

      # Build request body
      body =
        params
        |> Map.take([:content, :embeds])
        |> Map.update(:embeds, [], & &1)

      {:ok, %{url: url, body: body}}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Handles the Discord API response and transforms it into a standardized format.

  ## Examples

      iex> handler(%{"id" => "123", "content" => "Hello"}, _ctx)
      {:ok, %{status: "success", message: %{id: "123", content: "Hello", ...}}}

      iex> handler(%{"code" => 50001, "message" => "Missing Access"}, _ctx)
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}
  """
  @impl true
  def handler({:error, error}, _ctx), do: {:error, error}

  def handler(response, _ctx) when is_map(response) do
    case response do
      %{"id" => _} ->
        {:ok, %{
          status: "success",
          message: transform_message(response)
        }}

      %{"code" => code, "message" => error_message} ->
        Logger.error("Discord API error: #{code} - #{error_message}")
        {:error, %{
          type: "discord_api_error",
          code: code,
          message: error_message,
          context: %{
            endpoint: "messages",
            method: "POST"
          }
        }}

      %{"retry_after" => retry_after} ->
        Logger.warning("Discord rate limit hit, retry after #{retry_after}ms", %{retry_after: retry_after})
        {:error, %{
          type: "rate_limit",
          retry_after: retry_after
        }}

      _ ->
        Logger.error("Unexpected Discord API response: #{inspect(response)}")
        {:error, %{
          type: "unexpected_response",
          message: "Unexpected response format",
          response: response
        }}
    end
  end

  @doc """
  Transforms a Discord message into our standard format.
  """
  defp transform_message(message) do
    %{
      id: message["id"],
      channel_id: message["channel_id"],
      content: message["content"],
      timestamp: message["timestamp"]
    }
  end

  defp prism_url do
    __MODULE__.view().url
  end
end
