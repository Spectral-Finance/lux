defmodule Lux.Lenses.Twitter.TweetLens do
  @moduledoc """
  Lens to fetch specific tweets by their IDs.
  """
  use Lux.Lens,
    name: "Twitter Tweets",
    description: "Fetches Twitter tweets by IDs",
    url: "https://api.twitter.com/2/tweets",
    method: :get,
    auth: %{type: :custom, auth_function: &__MODULE__.auth/1},
    params: %{"tweet.fields" => "created_at,public_metrics,author_id"},
    schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "OAuth 2.0 Bearer token"},
        ids: %{type: :string, description: "Comma-separated list of Tweet IDs"}
      },
      required: ["token", "ids"]
    }

  @doc false
  def auth(lens) do
    token = lens.params[:token] || lens.params["token"]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  def before_focus(params) do
    # Remove token from query params to avoid passing it to Twitter API as a query param
    Map.drop(params, [:token, "token"])
  end

  def after_focus(%{"data" => data}) when is_list(data) do
    tweets =
      Enum.map(data, fn tweet_data ->
        %Lux.Lens.Twitter.Tweet{
          id: tweet_data["id"],
          text: tweet_data["text"],
          author_id: tweet_data["author_id"],
          created_at: tweet_data["created_at"],
          public_metrics: tweet_data["public_metrics"]
        }
      end)

    {:ok, tweets}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, List.first(errors)["detail"]}
  end

  def after_focus(response) do
    {:error, "Unknown error format: #{inspect(response)}"}
  end
end
