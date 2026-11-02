defmodule Lux.Prisms.Twitter.Automation.ManageFollows do
  @moduledoc """
  A prism for evaluating follow targets and identifying unfollow candidates safely.
  """

  use Lux.Prism,
    name: "Manage Twitter Follows",
    description: "Evaluates target profiles for follow recommendations and identifies stale non-mutuals for safe unfollowing",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'evaluate_target' or 'identify_unfollows'"},
        user: %{type: :object, description: "Target user profile for 'evaluate_target'"},
        target_keywords: %{type: :array, description: "Target niche keywords in user bio"},
        current_followers: %{type: :array, description: "List of follower IDs for 'identify_unfollows'"},
        whitelist: %{type: :array, description: "Protected user IDs for whitelist"},
        following_history: %{type: :object, description: "Map of user_id to follow ISO8601 timestamp"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Twitter.Automation.FollowManager

  def handler(params, _agent) when is_map(params) do
    action = to_string(Map.get(params, :action) || Map.get(params, "action", "evaluate_target"))

    case action do
      "evaluate_target" ->
        user = Map.get(params, :user) || Map.get(params, "user", %{})
        keywords = Map.get(params, :target_keywords) || Map.get(params, "target_keywords", [])

        {:ok, should_follow, score} = FollowManager.evaluate_target_user(user, keywords)

        {:ok,
         %{
           status: "evaluated",
           result: %{should_follow: should_follow, score: score}
         }}

      "identify_unfollows" ->
        whitelist = Map.get(params, :whitelist) || Map.get(params, "whitelist", [])
        current_followers = Map.get(params, :current_followers) || Map.get(params, "current_followers", [])
        state = FollowManager.init_state(whitelist)

        # Parse history
        history = Map.get(params, :following_history) || Map.get(params, "following_history", %{})

        state =
          Enum.reduce(history, state, fn {uid, ts_str}, acc ->
            case DateTime.from_iso8601(to_string(ts_str)) do
              {:ok, dt, _} -> FollowManager.record_follow(acc, uid, dt)
              _ -> acc
            end
          end)

        candidates = FollowManager.identify_unfollow_candidates(state, current_followers)

        {:ok,
         %{
           status: "identified",
           result: %{unfollow_candidates: candidates, count: length(candidates)}
         }}

      other ->
        {:error, "Unsupported action: #{other}"}
    end
  end

  def handler(_, _), do: {:error, "Invalid input"}
end
