defmodule Lux.Lenses.Twitter.Input do
  @moduledoc false

  @key_map %{
    "access_token" => :access_token,
    "bearer_token" => :bearer_token,
    "expansions" => :expansions,
    "max_results" => :max_results,
    "media.fields" => :media_fields,
    "media_fields" => :media_fields,
    "pagination_token" => :pagination_token,
    "place.fields" => :place_fields,
    "place_fields" => :place_fields,
    "plug" => :plug,
    "poll.fields" => :poll_fields,
    "poll_fields" => :poll_fields,
    "query" => :query,
    "tweet.fields" => :tweet_fields,
    "tweet_fields" => :tweet_fields,
    "tweet_id" => :tweet_id,
    "user.fields" => :user_fields,
    "user_fields" => :user_fields,
    "user_id" => :user_id,
    "username" => :username,
    "with_rate_limit" => :with_rate_limit
  }

  def normalize(input) when is_map(input) do
    Map.new(input, fn
      {key, value} when is_binary(key) -> {Map.get(@key_map, key, key), value}
      pair -> pair
    end)
  end

  def normalize(_input), do: %{}
end
