defmodule Lux.Agents.TwitterAgent do
  @moduledoc """
  An agent that manages Twitter interactions including auto-replies and scheduling.
  """

  use Lux.Agent,
    name: "Twitter Support Agent",
    description: "Monitors mentions and engages with users on X (Twitter)",
    goal: "Provide helpful and timely responses to users on Twitter",
    config: %{
      dry_run: true, # Safety first: default to dry run
      rules: %{
        min_followers: 10,
        exclude_keywords: ["spam", "scam", "crypto-giveaway"],
        include_keywords: [] # Empty means all
      }
    },
    lenses: [
      Lux.Lenses.Twitter.GetUserLens,
      Lux.Lenses.Twitter.MentionsLens
    ],
    prisms: [
      Lux.Prisms.Twitter.PostTweetPrism,
      Lux.Prisms.Twitter.AutoReplyPrism
    ],
    scheduled_actions: [
      # Check for mentions and reply every 5 minutes
      {Lux.Prisms.Twitter.AutoReplyPrism, 300_000, %{}, [name: "twitter_auto_reply"]}
    ]

  @doc """
  Schedules a specific tweet to be posted after a delay.
  """
  def schedule_tweet(agent_pid, text, delay_ms) do
    # Send message to the agent process to schedule the action
    Process.send_after(
      agent_pid,
      {:run_scheduled_action, "scheduled_tweet_#{Lux.UUID.generate()}",
       Lux.Prisms.Twitter.PostTweetPrism, delay_ms, %{text: text}, []},
      delay_ms
    )
  end
end
