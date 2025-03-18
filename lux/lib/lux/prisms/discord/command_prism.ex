defmodule Lux.Prisms.Discord.CommandPrism do
  @moduledoc """
  A prism for managing Discord command interactions.

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

  ## Message Types
  - PONG (1): Ping response
  - CHANNEL_MESSAGE (4): Regular message response
  - DEFERRED_CHANNEL_MESSAGE (5): Deferred response (15 minutes to respond)
  - DEFERRED_UPDATE_MESSAGE (6): Deferred message update
  - UPDATE_MESSAGE (7): Message update
  - AUTOCOMPLETE_RESULT (8): Autocomplete suggestions

  ## Message Flags
  - EPHEMERAL (64): Message only visible to the command user

  ## Examples
      # Reply to a command
      iex> Lux.Prisms.Discord.CommandPrism.run(%{
      ...>   action: "reply",
      ...>   interaction_id: "123456789",
      ...>   token: "interaction_token",
      ...>   type: 4,
      ...>   content: "Hello!"
      ...> })
      {:ok, %{status: "success"}}

      # Deferred response
      iex> Lux.Prisms.Discord.CommandPrism.run(%{
      ...>   action: "defer",
      ...>   interaction_id: "123456789",
      ...>   token: "interaction_token",
      ...>   flags: 64  # Ephemeral response
      ...> })
      {:ok, %{status: "success"}}

      # Update with components
      iex> Lux.Prisms.Discord.CommandPrism.run(%{
      ...>   action: "update",
      ...>   interaction_id: "123456789",
      ...>   token: "interaction_token",
      ...>   type: 7,
      ...>   components: [
      ...>     %{
      ...>       type: 1,  # Action Row
      ...>       components: [
      ...>         %{
      ...>           type: 2,  # Button
      ...>           label: "Click me!",
      ...>           custom_id: "button_1",
      ...>           style: 1  # Primary
      ...>         }
      ...>       ]
      ...>     }
      ...>   ]
      ...> })
      {:ok, %{status: "success"}}

  ## Error Cases
      # Invalid interaction ID
      iex> Lux.Prisms.Discord.CommandPrism.run(%{action: "reply", interaction_id: "invalid"})
      {:error, %{type: "validation_error", message: "Invalid interaction ID format"}}

      # Missing required fields
      iex> Lux.Prisms.Discord.CommandPrism.run(%{action: "reply"})
      {:error, %{type: "validation_error", message: "Missing required fields: interaction_id, token"}}

      # Rate limited
      iex> Lux.Prisms.Discord.CommandPrism.run(%{action: "reply", interaction_id: "123", token: "rate_limited"})
      {:error, %{type: "rate_limit", message: "Rate limited", retry_after: 5}}
  """

  use Lux.Prism,
    name: "Discord Command Manager",
    description: "Manages Discord command interactions and responses",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["reply", "defer", "update", "delete"],
          description: "Action to perform for the command response"
        },
        interaction_id: %{
          type: :string,
          description: "ID of the interaction to respond to",
          pattern: "^[0-9]{17,20}$"
        },
        token: %{
          type: :string,
          description: "Interaction token",
          minLength: 1
        },
        type: %{
          type: :integer,
          description: "Type of response",
          enum: [1, 2, 3, 4, 5, 6, 7, 8],
          mapping: %{
            1 => "PONG",
            4 => "CHANNEL_MESSAGE",
            5 => "DEFERRED_CHANNEL_MESSAGE",
            6 => "DEFERRED_UPDATE_MESSAGE",
            7 => "UPDATE_MESSAGE",
            8 => "APPLICATION_COMMAND_AUTOCOMPLETE_RESULT"
          }
        },
        content: %{
          type: :string,
          description: "Message content",
          maxLength: 2000
        },
        embeds: %{
          type: :array,
          description: "Message embeds",
          maxItems: 10,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string, maxLength: 256},
              description: %{type: :string, maxLength: 4096},
              url: %{type: :string},
              color: %{type: :integer},
              fields: %{
                type: :array,
                maxItems: 25,
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
          }
        },
        components: %{
          type: :array,
          description: "Message components",
          maxItems: 5,
          items: %{
            type: :object,
            properties: %{
              type: %{type: :integer, enum: [1, 2, 3, 4, 5, 6, 7, 8]},
              components: %{type: :array}
            },
            required: ["type"]
          }
        },
        flags: %{
          type: :integer,
          description: "Message flags. 64: Ephemeral",
          minimum: 0
        }
      },
      required: ["action"],
      allOf: [
        # Basic action requirements
        %{
          if: %{properties: %{action: %{const: "reply"}}},
          then: %{required: ["interaction_id", "token", "type"]}
        },
        %{
          if: %{properties: %{action: %{const: "defer"}}},
          then: %{required: ["interaction_id", "token"]}
        },
        %{
          if: %{properties: %{action: %{const: "update"}}},
          then: %{required: ["interaction_id", "token", "type"]}
        },
        %{
          if: %{properties: %{action: %{const: "delete"}}},
          then: %{required: ["interaction_id", "token"]}
        },
        # Response type specific validations
        %{
          if: %{
            properties: %{
              type: %{enum: [4, 7]} # Channel message or update
            }
          },
          then: %{
            anyOf: [
              %{required: ["content"]},
              %{required: ["embeds"]},
              %{required: ["components"]}
            ]
          }
        }
      ]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        data: %{
          type: :object,
          description: "Raw Discord API response"
        }
      },
      required: ["status"]
    }

  require Logger

  @base_url "https://discord.com/api/v10"
  @timeout :timer.seconds(10)
  @max_retries 3
  @retry_delay 1000 # 1 second

  # Message types
  @message_types %{
    pong: 1,
    channel_message: 4,
    deferred_channel_message: 5,
    deferred_update_message: 6,
    update_message: 7,
    autocomplete_result: 8
  }

  # Component types
  @component_types %{
    action_row: 1,
    button: 2,
    string_select: 3,
    text_input: 4,
    user_select: 5,
    role_select: 6,
    mentionable_select: 7,
    channel_select: 8
  }

  # Message flags
  @flags %{
    ephemeral: 64
  }

  @type interaction_response :: {:ok, map()} | {:error, map()}
  @type request_params :: %{
    method: :get | :post | :put | :patch | :delete,
    url: String.t(),
    body: map() | nil
  }
  @type validation_result :: {:ok, map()} | {:error, map()}

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
         {:ok, response} <- execute_request(request, @max_retries) do
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
  Executes the API request asynchronously with timeout handling and retries.
  """
  @spec execute_request(request_params(), non_neg_integer()) :: interaction_response()
  def execute_request(request, retries_left) do
    task = Task.async(fn ->
      try do
        make_request(request)
      rescue
        e in Req.Error ->
          {:error, %{type: "request_error", message: e.message}}
      end
    end)

    case Task.yield(task, @timeout) do
      {:ok, {:error, %{type: "rate_limit"} = error}} when retries_left > 0 ->
        Logger.warn("Rate limited by Discord API, retrying after #{error.retry_after} seconds")
        Process.sleep(error.retry_after * 1000)
        execute_request(request, retries_left - 1)

      {:ok, result} -> result

      nil ->
        Task.shutdown(task)
        Logger.error("Request timed out")
        {:error, %{type: "timeout", message: "Request timed out"}}
    end
  end

  # Private functions

  @spec make_request(request_params()) :: interaction_response()
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

  @spec handle_response(Req.Response.t()) :: interaction_response()
  defp handle_response(response) do
    case response do
      %{status: status, body: body} when status in 200..299 ->
        Logger.debug("Successful response from Discord API")
        {:ok, body}

      %{status: 429, headers: headers} ->
        retry_after = headers["retry-after"] || "5"
        Logger.warn("Rate limited by Discord API, retry after #{retry_after} seconds")
        {:error, %{
          type: "rate_limit",
          message: "Rate limited",
          retry_after: String.to_integer(retry_after)
        }}

      %{status: status, body: %{"code" => code, "message" => message}} ->
        Logger.error("Discord API error: [#{code}] #{message}")
        {:error, %{
          type: "discord_api_error",
          code: code,
          message: message,
          status: status
        }}

      _ ->
        Logger.error("Unexpected response from Discord API: #{inspect(response)}")
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
      data: response
    }}
  end

  @spec build_request(map()) :: request_params()
  defp build_request(%{action: "reply"} = params) do
    url = "#{@base_url}/interactions/#{params.interaction_id}/#{params.token}/callback"
    body = prepare_response_body(params)
    %{method: :post, url: url, body: body}
  end

  defp build_request(%{action: "defer"} = params) do
    url = "#{@base_url}/interactions/#{params.interaction_id}/#{params.token}/callback"
    body = %{
      type: @message_types.deferred_channel_message,
      data: %{
        flags: Map.get(params, :flags, 0)
      }
    }
    %{method: :post, url: url, body: body}
  end

  defp build_request(%{action: "update"} = params) do
    url = "#{@base_url}/webhooks/#{params.application_id}/#{params.token}/messages/@original"
    body = prepare_response_body(params)
    %{method: :patch, url: url, body: body}
  end

  defp build_request(%{action: "delete"} = params) do
    url = "#{@base_url}/webhooks/#{params.application_id}/#{params.token}/messages/@original"
    %{method: :delete, url: url}
  end

  @spec prepare_response_body(map()) :: map()
  defp prepare_response_body(params) do
    base_fields = [:content, :embeds, :components, :flags]
    data = Map.take(params, base_fields)

    %{
      type: params.type,
      data: data
    }
  end
end
