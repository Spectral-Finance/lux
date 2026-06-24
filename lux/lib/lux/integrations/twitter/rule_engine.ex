defmodule Lux.Integrations.Twitter.RuleEngine do
  @moduledoc """
  Rule-based engagement system.
  """

  @doc """
  Evaluates a tweet based on configured rules and returns an action.
  Actions can be:
  - {:reply, text}
  - :like
  - {:retweet, tweet_id}
  - :ignore
  """
  def evaluate(tweet_text) do
    cond do
      String.contains?(String.downcase(tweet_text), "help") ->
        {:reply, "How can we assist you?"}

      String.contains?(String.downcase(tweet_text), "awesome") ->
        :like

      String.length(tweet_text) > 200 ->
        :ignore

      true ->
        :ignore
    end
  end
end
