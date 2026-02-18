defmodule Lux.Prisms.Twitter.FollowerGrowthTrackerPrism do
  @moduledoc """
  Prism for tracking follower growth on Twitter.
  """

  alias Lux.{Client, Error}

  def track(client, user_id) do
    with {:ok, response} <- Client.get(client, "/1.1/users/show.json?id=#{user_id}") do
      {:ok, parse_growth(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp parse_growth(response) do
    %{
      followers_count: response["followers_count"],
      following_count: response["following_count"]
    }
  end
end

def track_follower_growth(client, user_id) do
  with {:ok, response} <- Client.get(client, "/1.1/users/show.json?id=#{user_id}") do
    {:ok, parse_follower_growth(response)}
  rescue
    e in Error -> {:error, e}
  end
end

defp parse_follower_growth(response) do
  %{
    current_followers: response["followers_count"],
    current_following: response["following_count"]
  }
end