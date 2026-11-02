defmodule Lux.Prisms.Discord.Channels.ListMessages do
  @moduledoc """
  A prism for retrieving messages from a Discord channel.
  """

  use Lux.Prism,
    name: "List Discord Messages",
    description: "Retrieves a list of messages from a Discord channel with pagination options",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        limit: %{type: :integer, description: "Max messages to return (1-100, default 50)"},
        around: %{type: :string, description: "Message ID around which to fetch"},
        before: %{type: :string, description: "Message ID before which to fetch"},
        after: %{type: :string, description: "Message ID after which to fetch"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string},
        messages: %{type: :array, items: %{type: :object}},
        count: %{type: :integer}
      },
      required: ["channel_id", "messages", "count"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} listing messages for Discord channel #{channel_id}")

      query_params =
        params
        |> Map.take([:limit, :around, :before, :after])
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> URI.encode_query()

      path =
        if query_params != "" do
          "/channels/#{channel_id}/messages?#{query_params}"
        else
          "/channels/#{channel_id}/messages"
        end

      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:get, path, opts) do
        {:ok, messages} when is_list(messages) ->
          {:ok, %{
            channel_id: channel_id,
            messages: messages,
            count: length(messages)
          }}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
