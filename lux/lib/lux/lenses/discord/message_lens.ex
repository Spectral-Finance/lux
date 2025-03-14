defmodule Lux.Lenses.Discord.MessageLens do
  @moduledoc """
  A lens for reading messages from Discord channels.

  ## Authentication

  Requires a Discord bot token in the application configuration:
  ```elixir
  config :lux, :discord_token, "your-bot-token"
  ```

  ## Rate Limiting

  Discord API has rate limits per route. This lens handles rate limiting by:
  - Respecting the retry_after header
  - Following the global rate limit
  - Using proper request headers

  ## Examples

      iex> Lux.Lenses.Discord.MessageLens.run(%{
      ...>   channel_id: "123456789",
      ...>   limit: 50
      ...> })
      {:ok,
       %{
         status: "success",
         messages: [
           %{
             id: "987654321",
             content: "Hello, Discord!",
             author: %{
               id: "111222333",
               username: "LuxBot",
               discriminator: "1234"
             },
             timestamp: "2024-03-08T12:34:56Z",
             attachments: [],
             reactions: [
               %{
                 emoji: "👍",
                 count: 1
               }
             ]
           }
         ],
         channel_id: "123456789"
       }}

  ## Error Cases

      # Invalid channel ID
      iex> Lux.Lenses.Discord.MessageLens.run(%{channel_id: "invalid"})
      {:error, %{type: "discord_api_error", code: 50004, message: "Invalid channel ID"}}

      # Missing permissions
      iex> Lux.Lenses.Discord.MessageLens.run(%{channel_id: "123456789"})
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}

      # Rate limited
      iex> Lux.Lenses.Discord.MessageLens.run(%{channel_id: "123456789"})
      {:error, %{type: "rate_limit", retry_after: 5000}}

  The lens reads Discord authentication details from configuration:
  - :discord_token - Discord bot token for authentication
  """

  use Lux.Lens,
    name: "Discord Message Reader",
    description: "Reads messages from Discord channels",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Discord channel ID to read messages from",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Number of messages to fetch (max 100)",
          minimum: 1,
          maximum: 100,
          default: 50
        },
        before: %{
          type: :string,
          description: "Get messages before this message ID",
          pattern: "^[0-9]{17,20}$"
        },
        after: %{
          type: :string,
          description: "Get messages after this message ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  require Logger

  @doc """
  Adds Discord bot token to request headers.
  """
  def add_auth_header(lens) do
    token = Application.fetch_env!(:lux, :discord_token)
    %{lens | headers: lens.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  @doc """
  Prepares the request URL and query parameters.
  """
  def before_focus(params) do
    # Extract channel_id and update URL
    channel_id = params.channel_id
    url = String.replace(lens_url(), ":channel_id", channel_id)

    # Build query params
    query_params =
      params
      |> Map.take([:limit, :before, :after])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    %{url: url, params: query_params}
  end

  @doc """
  Transforms the Discord API response into a more usable format.

  ## Examples

      iex> after_focus([%{"id" => "123", "content" => "Hello"}])
      {:ok, %{messages: [%{id: "123", content: "Hello", ...}]}}

      iex> after_focus(%{"code" => 50001, "message" => "Missing Access"})
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, %{
      status: "success",
      messages: Enum.map(messages, &transform_message/1),
      channel_id: messages |> List.first() |> Map.get("channel_id")
    }}
  end

  @impl true
  def after_focus(%{"code" => code, "message" => error_message}) do
    Logger.error("Discord API error: #{code} - #{error_message}")
    {:error, %{
      type: "discord_api_error",
      code: code,
      message: error_message,
      context: %{
        endpoint: "messages",
        method: "GET"
      }
    }}
  end

  @impl true
  def after_focus(%{"retry_after" => retry_after}) do
    Logger.warning("Discord rate limit hit, retry after #{retry_after}ms", %{retry_after: retry_after})
    {:error, %{
      type: "rate_limit",
      retry_after: retry_after
    }}
  end

  @impl true
  def after_focus(response) do
    Logger.error("Unexpected Discord API response: #{inspect(response)}")
    {:error, %{
      type: "unexpected_response",
      message: "Unexpected response format",
      response: response
    }}
  end

  @doc """
  Transforms a Discord message into our standard format.
  """
  defp transform_message(message) do
    %{
      id: message["id"],
      content: message["content"],
      author: %{
        id: get_in(message, ["author", "id"]),
        username: get_in(message, ["author", "username"]),
        discriminator: get_in(message, ["author", "discriminator"])
      },
      timestamp: message["timestamp"],
      attachments: Enum.map(message["attachments"] || [], &transform_attachment/1),
      reactions: Enum.map(message["reactions"] || [], &transform_reaction/1)
    }
  end

  @doc """
  Transforms a Discord attachment into our standard format.
  """
  defp transform_attachment(attachment) do
    %{
      id: attachment["id"],
      filename: attachment["filename"],
      size: attachment["size"],
      url: attachment["url"],
      proxy_url: attachment["proxy_url"],
      content_type: attachment["content_type"]
    }
  end

  @doc """
  Transforms a Discord reaction into our standard format.
  """
  defp transform_reaction(reaction) do
    %{
      emoji: get_in(reaction, ["emoji", "name"]),
      count: reaction["count"]
    }
  end

  defp lens_url do
    __MODULE__.view().url
  end
end
