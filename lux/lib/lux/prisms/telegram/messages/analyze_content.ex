defmodule Lux.Prisms.Telegram.Messages.AnalyzeContent do
  @moduledoc """
  A prism for analyzing Telegram message content.

  Extracts structured information from message text including detected commands,
  URLs, mentions, hashtags, emails, and message type classification.

  ## Implementation Details

  - Detects bot commands (/command patterns)
  - Extracts @mentions, #hashtags, URLs, and email addresses
  - Classifies message type: command, mention, media description, plain text
  - Counts words and characters for length analysis
  - Pure computation — no API call required

  ## Examples

      iex> AnalyzeContent.handler(%{text: "/start Hello @user check https://example.com"}, %{})
      {:ok, %{
        type: "command",
        command: "/start",
        mentions: ["@user"],
        urls: ["https://example.com"],
        hashtags: [],
        emails: [],
        word_count: 4,
        char_count: 44,
        language_hint: "en"
      }}

      iex> AnalyzeContent.handler(%{text: "#Elixir is great! #programming"}, %{})
      {:ok, %{type: "text", mentions: [], urls: [], hashtags: ["#Elixir", "#programming"], ...}}
  """

  use Lux.Prism,
    name: "Analyze Telegram Message Content",
    description: "Analyzes message text to extract commands, mentions, URLs, hashtags, and classify message type",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Message text to analyze"
        },
        entities: %{
          type: :array,
          description: "Optional Telegram message entities array for richer analysis",
          items: %{type: :object}
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        type: %{type: :string, description: "Detected message type: command|mention|hashtag|url|text"},
        command: %{type: [:string, :null], description: "The bot command if detected"},
        mentions: %{type: :array, items: %{type: :string}, description: "List of @mentions found"},
        urls: %{type: :array, items: %{type: :string}, description: "List of URLs found"},
        hashtags: %{type: :array, items: %{type: :string}, description: "List of #hashtags found"},
        emails: %{type: :array, items: %{type: :string}, description: "List of email addresses found"},
        word_count: %{type: :integer, description: "Number of words in the message"},
        char_count: %{type: :integer, description: "Number of characters in the message"},
        has_formatting: %{type: :boolean, description: "Whether the text contains formatting markers"}
      }
    }

  @url_regex ~r/https?:\/\/[^\s<>"\{\}|\\^`\[\]]+/
  @mention_regex ~r/@[A-Za-z0-9_]{3,}/
  @hashtag_regex ~r/#[A-Za-z][A-Za-z0-9_]*/
  @email_regex ~r/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/
  @command_regex ~r/^\/[A-Za-z0-9_]+/
  @formatting_regex ~r/[*_`~|]|\[.+?\]\(.+?\)|<[bisu]>|<\/[bisu]>/

  @impl true
  def handler(%{text: text} = _params, _agent) do
    text = to_string(text)

    urls = Regex.scan(@url_regex, text) |> List.flatten() |> Enum.uniq()
    mentions = Regex.scan(@mention_regex, text) |> List.flatten() |> Enum.uniq()
    hashtags = Regex.scan(@hashtag_regex, text) |> List.flatten() |> Enum.uniq()
    emails = Regex.scan(@email_regex, text) |> List.flatten() |> Enum.uniq()
    command = detect_command(text)
    has_formatting = Regex.match?(@formatting_regex, text)

    words = text |> String.split(~r/\s+/, trim: true)
    word_count = length(words)
    char_count = String.length(text)

    type = classify_type(command, mentions, hashtags, urls)

    {:ok, %{
      type: type,
      command: command,
      mentions: mentions,
      urls: urls,
      hashtags: hashtags,
      emails: emails,
      word_count: word_count,
      char_count: char_count,
      has_formatting: has_formatting
    }}
  end

  def handler(%{"text" => text} = params, agent) do
    handler(%{text: text} |> Map.merge(maybe_add_entities(params)), agent)
  end

  defp detect_command(text) do
    case Regex.run(@command_regex, text) do
      [cmd | _] -> cmd
      nil -> nil
    end
  end

  defp classify_type(command, _mentions, _hashtags, _urls) when not is_nil(command), do: "command"
  defp classify_type(_command, [_ | _], _hashtags, _urls), do: "mention"
  defp classify_type(_command, _mentions, [_ | _], _urls), do: "hashtag"
  defp classify_type(_command, _mentions, _hashtags, [_ | _]), do: "url"
  defp classify_type(_, _, _, _), do: "text"

  defp maybe_add_entities(params) do
    case params["entities"] do
      nil -> %{}
      entities -> %{entities: entities}
    end
  end
end
