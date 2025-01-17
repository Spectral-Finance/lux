defmodule Lux.Engine.Subscription.Pattern do
  @moduledoc """
  Provides pattern matching for signal subscriptions based on core signal attributes:
  - schema_id
  - sender
  - recipient

  Supports wildcards (* and ?) and regex patterns for flexible matching.
  """

  require Logger
  alias Lux.Signal

  @type t :: %__MODULE__{
          pattern: map(),
          priority: non_neg_integer(),
          wildcards: map(),
          regex_patterns: map()
        }

  defstruct pattern: %{},
            priority: 0,
            wildcards: %{},
            regex_patterns: %{}

  @doc """
  Creates a new pattern from a map and options.
  The pattern map can include exact values, wildcards (* and ?), and regex patterns
  for schema_id, sender and recipient.
  """
  def new(pattern_map, opts \\ []) do
    priority = Keyword.get(opts, :priority, 0)

    # Only allow matching on core signal attributes
    filtered_map = Map.take(pattern_map, [:schema_id, :sender, :recipient])

    {wildcards, remaining} = extract_wildcards(filtered_map)
    {regex_patterns, pattern} = extract_regex_patterns(remaining)

    %__MODULE__{
      pattern: pattern,
      priority: priority,
      wildcards: wildcards,
      regex_patterns: regex_patterns
    }
  end

  @doc """
  Checks if a signal matches the pattern based on core attributes.
  Returns {:ok, priority} if matched, :nomatch otherwise.
  """
  def match?(pattern, %Signal{} = signal) do
    signal_map = %{
      schema_id: signal.schema_id,
      sender: signal.sender,
      recipient: signal.recipient
    }

    Logger.debug("Checking if signal matches pattern",
      signal: signal_map,
      pattern: pattern.pattern,
      wildcards: pattern.wildcards,
      regex_patterns: pattern.regex_patterns
    )

    with :ok <- match_exact(pattern.pattern, signal_map),
         :ok <- match_wildcards(pattern.wildcards, signal_map),
         :ok <- match_regex(pattern.regex_patterns, signal_map) do
      {:ok, pattern.priority}
    else
      _ -> :nomatch
    end
  end

  # Private helpers

  defp match_exact(pattern, signal) do
    pattern_matches =
      Enum.all?(pattern, fn {key, value} ->
        case Map.get(signal, key) do
          nil -> false
          ^value -> true
          _ -> false
        end
      end)

    if pattern_matches, do: :ok, else: :nomatch
  end

  defp match_wildcards(wildcards, signal) do
    wildcards_match =
      Enum.all?(wildcards, fn {key, pattern} ->
        case Map.get(signal, key) do
          nil -> false
          value -> match_wildcard_pattern?(to_string(pattern), to_string(value))
        end
      end)

    if wildcards_match, do: :ok, else: :nomatch
  end

  defp match_regex(regex_patterns, signal) do
    regex_matches =
      Enum.all?(regex_patterns, fn {key, regex} ->
        case Map.get(signal, key) do
          nil -> false
          value -> Regex.match?(regex, to_string(value))
        end
      end)

    if regex_matches, do: :ok, else: :nomatch
  end

  defp match_wildcard_pattern?(pattern, value) do
    pattern
    |> String.split("*", trim: true)
    |> case do
      [] -> true
      parts -> parts |> Enum.join(".*") |> Regex.compile!() |> Regex.match?(value)
    end
  end

  defp extract_wildcards(pattern) do
    Enum.reduce(pattern, {%{}, %{}}, fn
      {key, value}, {wildcards, remaining} ->
        if String.contains?(to_string(value), ["*", "?"]) do
          {Map.put(wildcards, key, value), remaining}
        else
          {wildcards, Map.put(remaining, key, value)}
        end
    end)
  end

  defp extract_regex_patterns(pattern) do
    Enum.reduce(pattern, {%{}, %{}}, fn
      {key, "~r/" <> rest}, {regexes, remaining} ->
        pattern = String.slice(rest, 0, String.length(rest) - 1)

        case Regex.compile(pattern) do
          {:ok, regex} -> {Map.put(regexes, key, regex), remaining}
          {:error, _} -> {regexes, Map.put(remaining, key, "~r/" <> rest)}
        end

      {key, value}, {regexes, remaining} ->
        {regexes, Map.put(remaining, key, value)}
    end)
  end
end
