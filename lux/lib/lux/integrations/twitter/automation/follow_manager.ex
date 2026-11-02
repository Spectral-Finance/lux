defmodule Lux.Integrations.Twitter.Automation.FollowManager do
  @moduledoc """
  Manages targeted follow suggestions, reciprocal follow tracking,
  and safe unfollow pipelines with whitelist protections.
  """

  @type user_id :: String.t()

  @type follow_state :: %{
          whitelist: MapSet.t(user_id()),
          following_history: %{user_id() => DateTime.t()}
        }

  @doc """
  Initializes a new follow management state.
  """
  @spec init_state(list(user_id())) :: follow_state()
  def init_state(initial_whitelist \\ []) do
    %{
      whitelist: MapSet.new(Enum.map(initial_whitelist, &to_string/1)),
      following_history: %{}
    }
  end

  @doc """
  Adds user IDs to protected whitelist. Whitelisted users will never be unfollowed.
  """
  @spec add_to_whitelist(follow_state(), user_id() | list(user_id())) :: follow_state()
  def add_to_whitelist(state, user_ids) when is_list(user_ids) do
    new_set = MapSet.union(state.whitelist, MapSet.new(Enum.map(user_ids, &to_string/1)))
    %{state | whitelist: new_set}
  end

  def add_to_whitelist(state, user_id), do: add_to_whitelist(state, [user_id])

  @doc """
  Records a new follow action with timestamp.
  """
  @spec record_follow(follow_state(), user_id(), DateTime.t()) :: follow_state()
  def record_follow(state, user_id, timestamp \\ DateTime.utc_now()) do
    history = Map.put(state.following_history, to_string(user_id), timestamp)
    %{state | following_history: history}
  end

  @doc """
  Identifies users who can safely be unfollowed.
  Candidates are:
  - Following for longer than `grace_days` (default 7 days)
  - NOT in whitelist
  - NOT in `current_followers` list
  """
  @spec identify_unfollow_candidates(follow_state(), list(user_id()), pos_integer(), DateTime.t()) ::
          list(user_id())
  def identify_unfollow_candidates(state, current_followers, grace_days \\ 7, as_of \\ DateTime.utc_now()) do
    follower_set = MapSet.new(Enum.map(current_followers, &to_string/1))
    grace_seconds = grace_days * 86_400

    state.following_history
    |> Enum.filter(fn {user_id, followed_at} ->
      not MapSet.member?(state.whitelist, user_id) and
        not MapSet.member?(follower_set, user_id) and
        DateTime.diff(as_of, followed_at) >= grace_seconds
    end)
    |> Enum.map(fn {user_id, _} -> user_id end)
  end

  @doc """
  Evaluates a candidate user profile for targeted follow recommendations.
  Scores based on bio keyword matches and follower-to-following ratio.
  """
  @spec evaluate_target_user(map(), list(String.t())) :: {:ok, boolean(), float()}
  def evaluate_target_user(user, target_keywords) do
    bio = String.downcase(Map.get(user, :description) || Map.get(user, "description") || "")
    metrics = Map.get(user, :public_metrics) || Map.get(user, "public_metrics") || %{}

    followers = Map.get(metrics, :followers_count) || Map.get(metrics, "followers_count", 0)
    following = Map.get(metrics, :following_count) || Map.get(metrics, "following_count", 1)

    matched_keywords =
      Enum.count(target_keywords, fn kw -> String.contains?(bio, String.downcase(kw)) end)

    ratio = followers / max(1, following)

    score = matched_keywords * 25.0 + min(50.0, ratio * 20.0)
    should_follow = matched_keywords >= 1 and followers >= 100

    {:ok, should_follow, Float.round(score, 1)}
  end
end
