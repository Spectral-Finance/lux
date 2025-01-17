defmodule Lux.Engine.Subscription.Pattern do
  @moduledoc """
  Enhanced pattern matching for subscriptions with support for:
  - Wildcards and glob patterns
  - Regular expressions
  - Pattern priorities
  - Nested matching
  - Value transformations
  """

  @type t :: %__MODULE__{
          pattern: map(),
          priority: integer(),
          wildcards: map(),
          regex_patterns: map(),
          transformations: map()
        }

  defstruct pattern: %{},
            priority: 0,
            wildcards: %{},
            regex_patterns: %{},
            transformations: %{}

  @doc """
  Creates a new pattern with the given specifications.
  """
  def new(pattern, opts \\ []) do
    {wildcards, pattern} = extract_wildcards(pattern)
    {regex_patterns, pattern} = extract_regex_patterns(pattern)

    %__MODULE__{
      pattern: pattern,
      priority: Keyword.get(opts, :priority, 0),
      wildcards: wildcards,
      regex_patterns: regex_patterns,
      transformations: Keyword.get(opts, :transformations, %{})
    }
  end

  @doc """
  Checks if a signal matches the pattern.
  Returns {:ok, priority} if matched, :nomatch otherwise.
  """
  def match?(%__MODULE__{} = pattern, signal) when is_map(signal) do
    with :ok <- match_exact(pattern.pattern, signal),
         :ok <- match_wildcards(pattern.wildcards, signal),
         :ok <- match_regex(pattern.regex_patterns, signal) do
      {:ok, pattern.priority}
    else
      _ -> :nomatch
    end
  end

  @doc """
  Applies any transformations defined in the pattern to the signal.
  """
  def apply_transformations(%__MODULE__{transformations: trans}, signal) do
    Enum.reduce(trans, signal, fn {key, transformer}, acc ->
      case Map.get(signal, key) do
        nil -> acc
        value -> Map.put(acc, key, transformer.(value))
      end
    end)
  end

  # Private helpers

  defp match_exact(pattern, signal) do
    # If pattern is empty, it matches everything
    if pattern == %{} do
      :ok
    else
      # Check if any of the pattern fields match
      pattern_matches =
        Enum.any?(pattern, fn {key, value} ->
          case Map.get(signal, key) do
            ^value -> true
            _ -> false
          end
        end)

      if pattern_matches, do: :ok, else: :nomatch
    end
  end

  defp match_wildcards(wildcards, signal) do
    if Enum.all?(wildcards, fn {key, pattern} ->
         case Map.get(signal, key) do
           nil -> false
           value when is_binary(value) -> match_wildcard_pattern?(pattern, to_string(value))
           _ -> false
         end
       end) do
      :ok
    else
      :nomatch
    end
  end

  defp match_regex(regex_patterns, signal) do
    if Enum.all?(regex_patterns, fn {key, regex} ->
         case Map.get(signal, key) do
           nil -> false
           value when is_binary(value) -> Regex.match?(regex, value)
           _ -> false
         end
       end) do
      :ok
    else
      :nomatch
    end
  end

  defp match_wildcard_pattern?("*", _value), do: true

  defp match_wildcard_pattern?("?" <> rest, <<_::utf8, value_rest::binary>>),
    do: match_wildcard_pattern?(rest, value_rest)

  defp match_wildcard_pattern?("", ""), do: true

  defp match_wildcard_pattern?(pattern, value) do
    pattern_parts = String.split(pattern, "*")

    case pattern_parts do
      [prefix, suffix] ->
        String.starts_with?(value, prefix) and String.ends_with?(value, suffix)

      [exact] ->
        exact == value

      _ ->
        false
    end
  end

  defp extract_wildcards(pattern) do
    {wildcards, remaining} =
      Enum.split_with(pattern, fn {_key, value} ->
        is_binary(value) and String.contains?(value, ["*", "?"])
      end)

    {Map.new(wildcards), Map.new(remaining)}
  end

  defp extract_regex_patterns(pattern) do
    {regexes, remaining} =
      Enum.split_with(pattern, fn {_key, value} ->
        is_binary(value) and String.starts_with?(value, "~r/")
      end)

    regexes =
      Enum.map(regexes, fn {key, pattern} ->
        # Extract the pattern between ~r/ and the last /
        [_, regex_str] = Regex.run(~r/^~r\/(.+)\/$/, pattern)
        {key, Regex.compile!(regex_str)}
      end)

    {Map.new(regexes), Map.new(remaining)}
  end
end
