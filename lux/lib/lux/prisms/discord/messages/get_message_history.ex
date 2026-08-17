defmodule Lux.Prisms.Discord.Messages.GetMessageHistory do
  @moduledoc """
  A prism for retrieving Discord channel message history.

  Supports pagination with before/after/around parameters and limit control.
  """

  use Lux.Prism,
    name: "Get Discord Message History",
    description: "Retrieves message history from a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        limit: %{type: :integer, minimum: 1, maximum: 100, default: 50},
        before: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Get messages before this message ID"},
        after: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Get messages after this message ID"},
        around: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Get messages around this message ID"}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{type: :array, items: %{type: :object}},
        channel_id: %{type: :string},
        count: %{type: :integer}
      },
      required: ["messages", "channel_id", "count"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Retrieves message history from a Discord channel.

  Returns {:ok, %{messages: [...], channel_id: id, count: n}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, limit} <- Helpers.optional(params, :limit, 50),
         {:ok, query} <- build_query(params) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching message history for channel #{channel_id}")

      opts = Helpers.client_opts(params)

      case Client.request_with_retry(:get, "/channels/#{channel_id}/messages#{query}", opts) do
        {:ok, messages} when is_list(messages) ->
          {:ok, %{messages: messages, channel_id: channel_id, count: length(messages)}}

        {:ok, _} ->
          {:ok, %{messages: [], channel_id: channel_id, count: 0}}

        error ->
          Logger.error("Failed to fetch message history for #{channel_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp build_query(params) do
    query_parts = []

    if before = get_param(params, :before) do
      query_parts = ["before=#{before}" | query_parts]
    end

    if after = get_param(params, :after) do
      query_parts = ["after=#{after}" | query_parts]
    end

    if around = get_param(params, :around) do
      query_parts = ["around=#{around}" | query_parts]
    end

    if limit = get_param(params, :limit) do
      query_parts = ["limit=#{limit}" | query_parts]
    end

    query = if Enum.empty?(query_parts), do: "", else: "?" <> Enum.join(query_parts, "&")
    {:ok, query}
  end

  defp get_param(params, key) do
    Map.get(params, key, Map.get(params, Atom.to_string(key)))
  end
end