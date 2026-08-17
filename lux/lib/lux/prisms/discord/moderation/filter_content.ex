defmodule Lux.Prisms.Discord.Moderation.FilterContent do
  @moduledoc """
  A prism for checking message content against configurable word/pattern filters.

  Supports both exact word matching and regex pattern matching.
  Returns matched filters for moderation actions.
  """

  use Lux.Prism,
    name: "Filter Discord Message Content",
    description: "Checks message content against banned words/patterns",
    input_schema: %{
      type: :object,
      properties: %{
        content: %{type: :string, minLength: 1, maxLength: 4000},
        banned_words: %{type: :array, items: %{type: :string}, minItems: 1},
        banned_patterns: %{type: :array, items: %{type: :string}, description: "Regex patterns"},
        case_sensitive: %{type: :boolean, default: false}
      },
      required: ["content", "banned_words"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        filtered: %{type: :boolean},
        matches: %{type: :array, items: %{type: :object}},
        content: %{type: :string}
      },
      required: ["filtered", "matches", "content"]
    }

  require Logger

  @doc """
  Filters message content against banned words and patterns.

  Returns {:ok, %{filtered: boolean, matches: [...], content: ...}}.
  """
  def handler(params, _agent) do
    with {:ok, content} <- validate_string(params, :content),
         {:ok, banned_words} <- validate_string_list(params, :banned_words),
         {:ok, banned_patterns} <- validate_optional_string_list(params, :banned_patterns, []),
         {:ok, case_sensitive} <- optional(params, :case_sensitive, false) do

      search_content = if case_sensitive, do: content, else: String.downcase(content)
      
      word_matches = 
        banned_words
        |> Enum.filter(fn word ->
          search_word = if case_sensitive, do: word, else: String.downcase(word)
          String.contains?(search_content, search_word)
        end)
        |> Enum.map(fn word -> %{type: :word, match: word} end)

      pattern_matches =
        banned_patterns
        |> Enum.filter(fn pattern ->
          try do
            regex = if case_sensitive, do: ~r/#{pattern}/, else: ~r/#{pattern}/i
            Regex.match?(regex, content)
          rescue
            _ -> false
          end
        end)
        |> Enum.map(fn pattern -> %{type: :pattern, match: pattern} end)

      all_matches = word_matches ++ pattern_matches
      filtered = length(all_matches) > 0

      {:ok, %{filtered: filtered, matches: all_matches, content: content}}
    end
  end

  defp validate_string(params, key) do
    case Map.get(params, key, Map.get(params, Atom.to_string(key))) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_string_list(params, key, opts \\ []) do
    min = Keyword.get(opts, :min, 1)
    
    case Map.get(params, key, Map.get(params, Atom.to_string(key))) do
      values when is_list(values) and length(values) >= min ->
        if Enum.all?(values, &(is_binary(&1) and &1 != "")) do
          {:ok, values}
        else
          {:error, "Missing or invalid #{key}"}
        end
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_string_list(params, key, default) do
    case Map.get(params, key, Map.get(params, Atom.to_string(key))) do
      nil -> {:ok, default}
      values when is_list(values) -> {:ok, values}
      _ -> {:ok, default}
    end
  end

  defp optional(params, key, default) do
    {:ok, Map.get(params, key, Map.get(params, Atom.to_string(key), default))}
  end
end