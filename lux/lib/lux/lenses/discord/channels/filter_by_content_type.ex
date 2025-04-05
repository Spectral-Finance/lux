defmodule Lux.Lenses.Discord.Channels.FilterByContentType do
  @moduledoc """
  A lens for filtering Discord messages by content type in a channel.

  This lens provides a simple interface for filtering messages with:
  - Required parameters (channel_id, content_type)
  - Optional parameters (limit, before, after)
  - Direct Discord API error propagation
  - Clean response structure

  Content types supported:
  - `:attachments` - Messages with file attachments
  - `:embeds` - Messages with embeds (links, rich content)
  - `:files` - Messages with specific file types
  - `:links` - Messages containing URLs
  - `:videos` - Messages with video content
  - `:images` - Messages with image content

  ## Example
      iex> FilterByContentType.focus(%{
      ...>   channel_id: "123456789",
      ...>   content_type: :images,
      ...>   limit: 50
      ...> })
      {:ok, [
        %{
          id: "987654321",
          content: "Check out this image!",
          author: %{
            id: "444555666",
            username: "artist"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          attachments: [
            %{
              id: "111222333",
              filename: "artwork.png",
              content_type: "image/png",
              size: 1048576,
              url: "https://cdn.discordapp.com/attachments/123/456/artwork.png"
            }
          ]
        }
      ]}
  """

  alias Lux.Integrations.Discord

  @content_types [:attachments, :embeds, :files, :links, :videos, :images]

  use Lux.Lens,
    name: "Filter Discord Messages by Content Type",
    description: "Retrieves messages from a Discord channel filtered by specific content types such as images, videos, links, or file attachments",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to filter messages in",
          pattern: "^[0-9]{17,20}$"
        },
        content_type: %{
          type: :string,
          description: "Type of content to filter (attachments, embeds, files, links, videos, images)",
          enum: Enum.map(@content_types, &Atom.to_string/1)
        },
        file_type: %{
          type: :string,
          description: "Specific file extension to filter (e.g., 'pdf', 'png') when content_type is :files",
          pattern: "^[a-zA-Z0-9]+$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to return (1-100)",
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
      required: ["channel_id", "content_type"]
    }

  @doc """
  Transforms the Discord API response into a simplified message list format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, messages}` - List of messages with specified content type
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus([
      ...>   %{
      ...>     "id" => "987654321",
      ...>     "content" => "Check out this image!",
      ...>     "author" => %{
      ...>       "id" => "444555666",
      ...>       "username" => "artist"
      ...>     },
      ...>     "timestamp" => "2024-04-03T12:00:00.000000+00:00",
      ...>     "attachments" => [
      ...>       %{
      ...>         "id" => "111222333",
      ...>         "filename" => "artwork.png",
      ...>         "content_type" => "image/png",
      ...>         "size" => 1048576,
      ...>         "url" => "https://cdn.discordapp.com/attachments/123/456/artwork.png"
      ...>       }
      ...>     ]
      ...>   }
      ...> ])
      {:ok, [
        %{
          id: "987654321",
          content: "Check out this image!",
          author: %{
            id: "444555666",
            username: "artist"
          },
          timestamp: "2024-04-03T12:00:00.000000+00:00",
          attachments: [
            %{
              id: "111222333",
              filename: "artwork.png",
              content_type: "image/png",
              size: 1048576,
              url: "https://cdn.discordapp.com/attachments/123/456/artwork.png"
            }
          ]
        }
      ]}
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, Enum.map(messages, fn message ->
      %{
        id: message["id"],
        content: message["content"],
        author: %{
          id: message["author"]["id"],
          username: message["author"]["username"]
        },
        timestamp: message["timestamp"],
        attachments: Enum.map(message["attachments"] || [], fn attachment ->
          %{
            id: attachment["id"],
            filename: attachment["filename"],
            content_type: attachment["content_type"],
            size: attachment["size"],
            url: attachment["url"]
          }
        end),
        embeds: message["embeds"] || []
      }
    end)}
  end

  def after_focus(%{"message" => message}), do: {:error, %{"message" => message}}

  @doc """
  Prepares the request parameters by converting content type filters into query parameters.
  """
  def before_focus(%{content_type: content_type} = params) do
    has_content = String.to_existing_atom(content_type)

    query = [
      has: has_content,
      limit: Map.get(params, :limit, 50)
    ]

    case params do
      %{file_type: file_type} when has_content == :files ->
        [{:has, "#{has_content}.#{file_type}"} | Enum.drop(query, 1)]
      _ ->
        query
    end
  end
end
