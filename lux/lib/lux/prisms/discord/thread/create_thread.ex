defmodule Lux.Prisms.Discord.Thread.CreateThread do
  @moduledoc """
  A prism for creating threads in a Discord channel.

  This prism provides a simple interface for creating Discord threads with:
  - Required parameters (channel_id, name)
  - Optional parameters (message_id, auto_archive_duration, rate_limit_per_user)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      # Create a thread from a message
      iex> CreateThread.handler(%{
      ...>   channel_id: "123456789",
      ...>   message_id: "987654321",
      ...>   name: "Discussion Thread",
      ...>   auto_archive_duration: 60
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        thread_id: "111111111111111111",
        name: "Discussion Thread",
        channel_id: "123456789"
      }}

      # Create a thread without a message
      iex> CreateThread.handler(%{
      ...>   channel_id: "123456789",
      ...>   name: "General Discussion",
      ...>   auto_archive_duration: 1440,
      ...>   rate_limit_per_user: 10
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        thread_id: "111111111111111111",
        name: "General Discussion",
        channel_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Create Discord Thread",
    description: "Creates a thread in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to create the thread in",
          pattern: "^[0-9]{17,20}$"
        },
        message_id: %{
          type: :string,
          description: "The ID of the message to create the thread from (optional)",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the thread",
          minLength: 1,
          maxLength: 100
        },
        auto_archive_duration: %{
          type: :integer,
          description: "Duration in minutes to automatically archive the thread (60, 1440, 4320, 10_080)",
          enum: [60, 1440, 4320, 10_080],
          default: 1440
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Amount of seconds a user has to wait before sending another message (0-21_600)",
          minimum: 0,
          maximum: 21_600,
          default: 0
        }
      },
      required: ["channel_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the thread was successfully created"
        },
        thread_id: %{
          type: :string,
          description: "The ID of the created thread"
        },
        name: %{
          type: :string,
          description: "The name of the created thread"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel where the thread was created"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to create a thread in a Discord channel.

  Returns {:ok, %{created: true, thread_id: id, name: name, channel_id: channel_id}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, message_id} <- validate_optional_param(params, :message_id),
         {:ok, auto_archive_duration} <- validate_optional_param(params, :auto_archive_duration, 1440),
         {:ok, rate_limit_per_user} <- validate_optional_param(params, :rate_limit_per_user, 0) do

      agent_name = agent[:name] || "Unknown Agent"
      thread_type = if message_id, do: "from message #{message_id}", else: "without message"
      Logger.info("Agent #{agent_name} creating thread #{thread_type} in channel #{channel_id}")

      request_path = build_request_path(channel_id, message_id)
      request_body = build_request_body(name, auto_archive_duration, rate_limit_per_user)

      case Client.request(:post, request_path, %{json: request_body}) do
        {:ok, %{"id" => thread_id}} ->
          Logger.info("Successfully created thread #{thread_id} in channel #{channel_id}")
          {:ok, %{created: true, thread_id: thread_id, name: name, channel_id: channel_id}}
        error ->
          Logger.error("Failed to create thread in channel #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end

  defp build_request_path(channel_id, nil), do: "/channels/#{channel_id}/threads"
  defp build_request_path(channel_id, message_id), do: "/channels/#{channel_id}/messages/#{message_id}/threads"

  defp build_request_body(name, auto_archive_duration, rate_limit_per_user) do
    %{name: name}
    |> maybe_add_param(:auto_archive_duration, auto_archive_duration)
    |> maybe_add_param(:rate_limit_per_user, rate_limit_per_user)
  end

  defp maybe_add_param(map, _key, nil), do: map
  defp maybe_add_param(map, key, value), do: Map.put(map, key, value)
end
