defmodule Lux.Prisms.Discord.ChannelPrism do
  @moduledoc """
  A prism for managing Discord channels.

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

  ## Examples
      # Create a channel
      iex> Lux.Prisms.Discord.ChannelPrism.run(%{
      ...>   action: "create",
      ...>   guild_id: "123456789",
      ...>   name: "general",
      ...>   type: 0
      ...> })
      {:ok, %{status: "success", channel: %{"id" => "987654321", ...}}}

      # Update permissions
      iex> Lux.Prisms.Discord.ChannelPrism.run(%{
      ...>   action: "set_permissions",
      ...>   channel_id: "987654321",
      ...>   overwrite_id: "111222333",
      ...>   allow: "1024",
      ...>   deny: "0"
      ...> })
      {:ok, %{status: "success"}}

  ## Error Cases
      # Invalid ID format
      iex> Lux.Prisms.Discord.ChannelPrism.run(%{action: "create", guild_id: "invalid"})
      {:error, %{type: "validation_error", message: "Invalid guild ID format"}}

      # Missing permissions
      iex> Lux.Prisms.Discord.ChannelPrism.run(%{action: "create", guild_id: "123456789"})
      {:error, %{type: "discord_api_error", code: 50001, message: "Missing Access"}}
  """

  use Lux.Prism,
    name: "Discord Channel Manager",
    description: "Manages Discord channels and their permissions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create", "update", "delete", "set_permissions"],
          description: "Action to perform on the channel"
        },
        guild_id: %{
          type: :string,
          description: "ID of the guild (required for create)",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "ID of the channel (required for update/delete/permissions)",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "Channel name (1-100 characters)",
          maxLength: 100,
          minLength: 1
        },
        type: %{
          type: :integer,
          description: "Channel type",
          enum: [0, 2, 4, 5, 10, 11, 12, 13, 14, 15, 16],
          mapping: %{
            0 => "GUILD_TEXT",
            2 => "GUILD_VOICE",
            4 => "GUILD_CATEGORY",
            5 => "GUILD_ANNOUNCEMENT",
            10 => "ANNOUNCEMENT_THREAD",
            11 => "PUBLIC_THREAD",
            12 => "PRIVATE_THREAD",
            13 => "GUILD_STAGE_VOICE",
            14 => "GUILD_DIRECTORY",
            15 => "GUILD_FORUM",
            16 => "GUILD_MEDIA"
          }
        },
        topic: %{
          type: :string,
          description: "Channel topic (0-1024 characters for normal channels, 0-4096 for forum channels)",
          maxLength: 4096
        },
        position: %{
          type: :integer,
          description: "Position of the channel in the left-hand listing",
          minimum: 0
        },
        nsfw: %{
          type: :boolean,
          description: "Whether the channel is NSFW"
        },
        parent_id: %{
          type: :string,
          description: "ID of the parent category (each category can contain up to 50 channels)",
          pattern: "^[0-9]{17,20}$"
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Slowmode rate limit per user in seconds (0-21600)",
          minimum: 0,
          maximum: 21600
        },
        bitrate: %{
          type: :integer,
          description: "Voice channel bitrate in bits (8000 to 96000 or 128000 for VIP servers)",
          minimum: 8000,
          maximum: 128000
        },
        user_limit: %{
          type: :integer,
          description: "Voice channel user limit (0 for unlimited, 1-99 for limit)",
          minimum: 0,
          maximum: 99
        },
        rtc_region: %{
          type: :string,
          description: "Voice channel region override (null for automatic)",
          nullable: true
        },
        video_quality_mode: %{
          type: :integer,
          description: "Video quality mode of the voice channel (1: auto, 2: 720p)",
          enum: [1, 2]
        },
        default_auto_archive_duration: %{
          type: :integer,
          description: "Default thread auto-archive duration in minutes",
          enum: [60, 1440, 4320, 10080]
        },
        default_thread_rate_limit_per_user: %{
          type: :integer,
          description: "Default rate limit per user for newly created threads",
          minimum: 0,
          maximum: 21600
        },
        available_tags: %{
          type: :array,
          description: "Available tags for forum/media channels (max 20)",
          maxItems: 20,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              name: %{type: :string, maxLength: 20},
              moderated: %{type: :boolean},
              emoji_id: %{
                type: :string,
                nullable: true,
                pattern: "^[0-9]{17,20}$"
              },
              emoji_name: %{
                type: :string,
                nullable: true,
                maxLength: 32
              }
            },
            required: ["name"]
          }
        },
        default_reaction_emoji: %{
          type: :object,
          description: "Default reaction emoji for forum posts",
          properties: %{
            emoji_id: %{
              type: :string,
              nullable: true,
              pattern: "^[0-9]{17,20}$"
            },
            emoji_name: %{
              type: :string,
              nullable: true,
              maxLength: 32
            }
          }
        },
        default_forum_layout: %{
          type: :integer,
          description: "Default layout for forum channels",
          enum: [0, 1, 2],
          mapping: %{
            0 => "NOT_SET",
            1 => "LIST_VIEW",
            2 => "GALLERY_VIEW"
          }
        },
        default_sort_order: %{
          type: :integer,
          description: "Default sort order for forum channels",
          enum: [0, 1],
          mapping: %{
            0 => "LATEST_ACTIVITY",
            1 => "CREATION_DATE"
          }
        },
        flags: %{
          type: :integer,
          description: "Channel flags combined as a bitfield. 1 << 0: PINNED, 1 << 1: REQUIRE_TAG",
          minimum: 0
        },
        overwrite_id: %{
          type: :string,
          description: "ID of the role or user to set permissions for",
          pattern: "^[0-9]{17,20}$"
        },
        allow: %{
          type: :string,
          description: "Allowed permission bits as string",
          pattern: "^[0-9]+$"
        },
        deny: %{
          type: :string,
          description: "Denied permission bits as string",
          pattern: "^[0-9]+$"
        }
      },
      required: ["action"],
      allOf: [
        # Basic action requirements
        %{
          if: %{properties: %{action: %{const: "create"}}},
          then: %{required: ["guild_id", "name", "type"]}
        },
        %{
          if: %{properties: %{action: %{const: "update"}}},
          then: %{required: ["channel_id"]}
        },
        %{
          if: %{properties: %{action: %{const: "delete"}}},
          then: %{required: ["channel_id"]}
        },
        %{
          if: %{properties: %{action: %{const: "set_permissions"}}},
          then: %{required: ["channel_id", "overwrite_id", "allow", "deny"]}
        },
        # Channel type specific validations
        %{
          if: %{
            properties: %{
              type: %{enum: [2, 13]} # Voice channels
            }
          },
          then: %{
            properties: %{
              topic: %{maxLength: 1024},
              bitrate: %{type: :integer},
              user_limit: %{type: :integer},
              rtc_region: %{type: :string},
              video_quality_mode: %{type: :integer}
            }
          }
        },
        %{
          if: %{
            properties: %{
              type: %{enum: [15, 16]} # Forum/Media channels
            }
          },
          then: %{
            properties: %{
              topic: %{maxLength: 4096},
              available_tags: %{type: :array},
              default_reaction_emoji: %{type: :object},
              default_forum_layout: %{type: :integer},
              default_sort_order: %{type: :integer}
            }
          }
        }
      ]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        channel: %{
          type: :object,
          description: "Raw Discord API response"
        }
      },
      required: ["status"]
    }

  require Logger

  @base_url "https://discord.com/api/v10"
  @timeout :timer.seconds(10)

  @type api_response :: {:ok, map()} | {:error, map()}
  @type validation_result :: {:ok, map()} | {:error, map()}
  @type request_params :: %{
    method: :get | :post | :put | :patch | :delete,
    url: String.t(),
    body: map() | nil
  }

  @doc """
  Adds Discord bot token to request headers.
  """
  def add_auth_header(prism) do
    token = Application.fetch_env!(:lux, :discord_token)
    %{prism | headers: prism.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  @doc """
  Handles the Discord API request with proper error handling and timeout management.
  """
  @impl true
  def handler(input, ctx) do
    with {:ok, request} <- prepare_request(input),
         {:ok, response} <- execute_request(request) do
      format_response(response)
    end
  end

  @doc """
  Prepares the API request based on validated parameters.
  """
  @spec prepare_request(map()) :: {:ok, request_params()} | {:error, map()}
  def prepare_request(params) do
    try do
      request = build_request(params)
      {:ok, request}
    rescue
      e in RuntimeError ->
        Logger.error("Error preparing request: #{inspect(e)}")
        {:error, %{type: "preparation_error", message: e.message}}
    end
  end

  @doc """
  Executes the API request asynchronously with timeout handling.
  """
  @spec execute_request(request_params()) :: api_response()
  def execute_request(request) do
    task = Task.async(fn ->
      try do
        make_request(request)
      rescue
        e in Req.Error ->
          {:error, %{type: "request_error", message: e.message}}
      end
    end)

    case Task.yield(task, @timeout) do
      {:ok, result} -> result
      nil ->
        Task.shutdown(task)
        {:error, %{type: "timeout", message: "Request timed out"}}
    end
  end

  # Private functions

  @spec make_request(request_params()) :: api_response()
  defp make_request(%{method: method, url: url, body: body}) do
    headers = [
      {"Authorization", "Bot #{Application.fetch_env!(:lux, :discord_token)}"},
      {"Content-Type", "application/json"}
    ]

    response = case method do
      :get -> Req.get!(url, headers: headers)
      :post -> Req.post!(url, json: body, headers: headers)
      :put -> Req.put!(url, json: body, headers: headers)
      :patch -> Req.patch!(url, json: body, headers: headers)
      :delete -> Req.delete!(url, headers: headers)
    end

    handle_response(response)
  end

  @spec handle_response(Req.Response.t()) :: api_response()
  defp handle_response(response) do
    case response do
      %{status: status, body: body} when status in 200..299 ->
        {:ok, body}
      %{status: 429, headers: headers} ->
        retry_after = headers["retry-after"] || "5"
        {:error, %{
          type: "rate_limit",
          message: "Rate limited",
          retry_after: String.to_integer(retry_after)
        }}
      %{status: status, body: %{"code" => code, "message" => message}} ->
        {:error, %{
          type: "discord_api_error",
          code: code,
          message: message,
          status: status
        }}
      _ ->
        {:error, %{
          type: "unknown_error",
          message: "An unexpected error occurred",
          status: response.status
        }}
    end
  end

  @spec format_response(map() | {:error, map()}) :: {:ok, map()} | {:error, map()}
  defp format_response({:error, _} = error), do: error
  defp format_response(response) do
    {:ok, %{
      status: "success",
      channel: response
    }}
  end

  defp build_request(%{action: "create"} = params) do
    url = "#{@base_url}/guilds/#{params.guild_id}/channels"
    body = prepare_channel_body(params)
    %{method: :post, url: url, body: body}
  end

  defp build_request(%{action: "update"} = params) do
    url = "#{@base_url}/channels/#{params.channel_id}"
    body = prepare_channel_body(params)
    %{method: :patch, url: url, body: body}
  end

  defp build_request(%{action: "delete"} = params) do
    url = "#{@base_url}/channels/#{params.channel_id}"
    %{method: :delete, url: url}
  end

  defp build_request(%{action: "set_permissions"} = params) do
    url = "#{@base_url}/channels/#{params.channel_id}/permissions/#{params.overwrite_id}"
    body = %{
      allow: params.allow,
      deny: params.deny,
      type: if(String.length(params.overwrite_id) > 18, do: 1, else: 0)
    }
    %{method: :put, url: url, body: body}
  end

  defp prepare_channel_body(params) do
    base_fields = [
      :name, :type, :topic, :position, :nsfw, :parent_id,
      :rate_limit_per_user, :bitrate, :user_limit, :rtc_region,
      :video_quality_mode, :default_auto_archive_duration,
      :default_thread_rate_limit_per_user, :flags
    ]

    forum_fields = [
      :available_tags, :default_reaction_emoji,
      :default_forum_layout, :default_sort_order
    ]

    fields = if params[:type] in [15, 16] do
      base_fields ++ forum_fields
    else
      base_fields
    end

    Map.take(params, fields)
  end
end
