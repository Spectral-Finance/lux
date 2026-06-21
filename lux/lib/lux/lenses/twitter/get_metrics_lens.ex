defmodule Lux.Lenses.Twitter.GetMetricsLens do
  @moduledoc """
  Lens for fetching engagement metrics for the authenticated user's tweets.
  """

  use Lux.Lens,
    name: "Twitter.GetMetrics",
    description: "Retrieves public metrics for the authenticated user's recent tweets",
    url: "https://api.twitter.com/2/users/me/tweets",
    method: :get,
    params: %{
      "tweet.fields" => "public_metrics,created_at",
      "max_results" => 10
    }

  @impl true
  def after_focus(response) do
    case response do
      {:ok, %{"data" => tweets}} ->
        metrics = Enum.map(tweets, fn t -> 
          %{
            id: t["id"],
            text: String.slice(t["text"], 0, 50) <> "...",
            created_at: t["created_at"],
            retweet_count: get_in(t, ["public_metrics", "retweet_count"]),
            reply_count: get_in(t, ["public_metrics", "reply_count"]),
            like_count: get_in(t, ["public_metrics", "like_count"]),
            quote_count: get_in(t, ["public_metrics", "quote_count"]),
            impression_count: get_in(t, ["public_metrics", "impression_count"])
          }
        end)
        {:ok, metrics}
      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, []}
      other -> other
    end
  end
end
