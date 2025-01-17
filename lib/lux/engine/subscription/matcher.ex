defmodule Lux.Engine.Subscription.Matcher do
  @moduledoc """
  Handles pattern matching logic between signals and subscriptions.
  Provides efficient matching algorithms using ETS match specifications.
  """

  @doc """
  Creates a match specification for finding subscriptions that match a signal.
  The match spec will match if all fields in the pattern exist in the signal
  with the same values.
  """
  def build_match_spec(signal) when is_map(signal) do
    match_head = {{:"$1", :_}, {:_, :"$2"}}

    # Build guard conditions for each field in the signal
    guards =
      signal
      |> Enum.map(fn {key, value} ->
        {:==, {:map_get, key, :"$1"}, {:const, value}}
      end)

    result = [:"$2"]

    [{match_head, guards, result}]
  end

  @doc """
  Checks if a subscription pattern matches a signal.
  Returns true if all fields in the pattern exist in the signal with the same values.
  """
  def matches?(pattern, signal) when is_map(pattern) and is_map(signal) do
    Enum.all?(pattern, fn {key, value} ->
      case Map.get(signal, key) do
        ^value -> true
        _ -> false
      end
    end)
  end
end
