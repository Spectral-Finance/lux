defmodule Lux.Beams.Twitter.AutomationBeam do
  @moduledoc """
  A beam pipeline that orchestrates Twitter automated engagement and scheduled interactions:
  1. Ingests incoming tweets or mentions
  2. Evaluates engagement rules and rate-limit safety caps
  3. Generates contextual auto-replies
  4. Dispatches or queues scheduled interactions
  """

  use Lux.Beam,
    name: "Twitter Automation & Engagement Pipeline",
    description: "Orchestrates tweet evaluation, auto-reply generation, and automated scheduling queue",
    input_schema: %{
      type: :object,
      properties: %{
        tweet: %{type: :object, description: "Incoming tweet or mention"},
        rules: %{type: :array, description: "Declarative engagement rules"},
        daily_usage: %{type: :object, description: "Current action counters today"},
        scheduled_at: %{type: :string, description: "Optional schedule timestamp"}
      },
      required: ["tweet"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        engagement_evaluation: %{type: :object},
        auto_reply: %{type: :object}
      },
      required: ["engagement_evaluation", "auto_reply"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Twitter.Automation.EvaluateEngagementRules
  alias Lux.Prisms.Twitter.Automation.ProcessAutoReply

  sequence do
    # 1. Evaluate engagement rules
    step(:engagement_evaluation, EvaluateEngagementRules, %{
      tweet: [:input, :tweet],
      rules: [:input, :rules],
      daily_usage: [:input, :daily_usage]
    })

    # 2. Process auto reply
    step(:auto_reply, ProcessAutoReply, %{
      tweet: [:input, :tweet]
    })
  end

  @doc """
  Direct execution helper for processing a tweet through the automation pipeline.
  """
  def process_tweet(tweet, opts \\ []) do
    rules = Keyword.get(opts, :rules, [])
    daily_usage = Keyword.get(opts, :daily_usage, %{})
    cooldown_state = Keyword.get(opts, :cooldown_state, %{})

    with {:ok, eval_res} <-
           EvaluateEngagementRules.handler(%{tweet: tweet, rules: rules, daily_usage: daily_usage}, %{}),
         {:ok, reply_res} <-
           ProcessAutoReply.handler(%{tweet: tweet, cooldown_state: cooldown_state}, %{}) do
      {:ok,
       %{
         engagement_evaluation: eval_res,
         auto_reply: reply_res
       }}
    end
  end
end
