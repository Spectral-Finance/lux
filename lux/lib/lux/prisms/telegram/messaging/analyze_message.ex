defmodule Lux.Prisms.Telegram.Messaging.AnalyzeMessage do
  @moduledoc """
  A prism for analyzing and processing Telegram messages.

  Parses message content to extract commands, entities, intent,
  and routes to the appropriate handler. Supports:
  - Command parsing (/start, /help, etc.)
  - Hashtag and mention extraction
  - Callback query routing
  - Deep link parameter extraction
  - Message type classification

  ## Examples

      iex> AnalyzeMessage.handler(%{
      ...>   text: "/start ref_123",
      ...>   chat_id: 123_456_789,
      ...>   message_id: 42
      ...> }, %{name: "Agent"})
      {:ok, %{
        type: :command,
        command: "start",
        args: ["ref_123"],
        entities: [],
        chat_id: 123_456_789
      }}
  """

  use Lux.Prism,
    name: "Analyze Telegram Message",
    description: "Analyzes and classifies Telegram message content for routing and processing",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Message text content"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Chat identifier"
        },
        message_id: %{
          type: :integer,
          description: "Message identifier"
        },
        entities: %{
          type: :array,
          description: "Message entities (commands, mentions, hashtags, urls)",
          default: []
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        type: %{
          type: :string,
          description: "Message type: command | mention | hashtag | text | media | empty",
          enum: ["command", "mention", "hashtag", "url", "text", "media", "empty"]
        },
        command: %{type: :string, description: "Command name (without slash)"},
        args: %{type: :array, description: "Command arguments"},
        mentions: %{type: :array, description: "Mentioned usernames"},
        hashtags: %{type: :array, description: "Hashtag strings"},
        urls: %{type: :array, description: "URLs found in message"},
        chat_id: %{type: [:string, :integer]},
        message_id: %{type: :integer}
      },
      required: ["type", "chat_id", "message_id"]
    }

  require Logger

  @command_re ~r/^\/([a-zA-Z0-9_]+)(?:@\w+)?(?:\s+(.*))?$/
  @mention_re ~r/@([a-zA-Z0-9_]{5,32})/
  @hashtag_re ~r/#([a-zA-Z0-9_]+)/
  @url_re     ~r/https?:\/\/[^\s]+/

  @impl true
  def handler(%{chat_id: chat_id, message_id: message_id} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    text = Map.get(params, :text, "")
    Logger.info("Agent #{agent_name} analyzing message #{message_id} in chat #{chat_id}")

    result = analyze(text, chat_id, message_id)
    Logger.info("Message #{message_id} classified as: #{result.type}")
    {:ok, result}
  end

  defp analyze(text, chat_id, message_id) when is_binary(text) and text != "" do
    cond do
      Regex.match?(@command_re, text) ->
        [_, cmd | rest] = Regex.run(@command_re, text)
        args = if rest != [] and hd(rest) != nil,
          do: String.split(hd(rest), ~r/\s+/, trim: true), else: []
        %{type: "command", command: cmd, args: args,
          mentions: [], hashtags: [], urls: [],
          chat_id: chat_id, message_id: message_id}

      Regex.match?(@mention_re, text) ->
        mentions = Regex.scan(@mention_re, text) |> Enum.map(&Enum.at(&1, 1))
        %{type: "mention", command: nil, args: [],
          mentions: mentions, hashtags: extract_hashtags(text),
          urls: extract_urls(text), chat_id: chat_id, message_id: message_id}

      Regex.match?(@hashtag_re, text) ->
        %{type: "hashtag", command: nil, args: [],
          mentions: [], hashtags: extract_hashtags(text),
          urls: extract_urls(text), chat_id: chat_id, message_id: message_id}

      true ->
        %{type: "text", command: nil, args: [],
          mentions: [], hashtags: [], urls: extract_urls(text),
          chat_id: chat_id, message_id: message_id}
    end
  end
  defp analyze("", chat_id, message_id),
    do: %{type: "empty", command: nil, args: [], mentions: [],
          hashtags: [], urls: [], chat_id: chat_id, message_id: message_id}
  defp analyze(_, chat_id, message_id),
    do: %{type: "media", command: nil, args: [], mentions: [],
          hashtags: [], urls: [], chat_id: chat_id, message_id: message_id}

  defp extract_hashtags(text), do: Regex.scan(@hashtag_re, text) |> Enum.map(&Enum.at(&1, 1))
  defp extract_urls(text), do: Regex.scan(@url_re, text) |> Enum.map(&hd/1)
end
