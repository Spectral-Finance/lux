defmodule Lux.Prisms.Twitter.Automation.ProcessAutoReply do
  @moduledoc """
  A prism for evaluating mentions, verifying cooldowns, and generating automated replies.
  """

  use Lux.Prism,
    name: "Process Twitter Auto-Reply",
    description: "Evaluates mention eligibility, checks cooldowns, and creates contextual reply texts",
    input_schema: %{
      type: :object,
      properties: %{
        tweet: %{type: :object, description: "Incoming mention or tweet payload"},
        cooldown_state: %{type: :object, description: "Map of user_id to last reply timestamp"},
        bot_id: %{type: :string, description: "The ID of the bot account"},
        templates: %{type: :object, description: "Custom response templates"}
      },
      required: ["tweet"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        should_reply: %{type: :boolean},
        reason: %{type: :string},
        reply_text: %{type: [:string, :null]}
      },
      required: ["should_reply", "reason"]
    }

  alias Lux.Integrations.Twitter.Automation.AutoReplyManager

  def handler(params, _agent) when is_map(params) do
    tweet = Map.get(params, :tweet) || Map.get(params, "tweet") || params
    cooldown_state = Map.get(params, :cooldown_state) || Map.get(params, "cooldown_state") || %{}
    bot_id = Map.get(params, :bot_id) || Map.get(params, "bot_id", "my_bot")
    templates = Map.get(params, :templates) || Map.get(params, "templates") || %{}

    config = %{bot_id: bot_id}

    with {:ok, eligible, reason} <- AutoReplyManager.should_reply?(tweet, cooldown_state, config) do
      if eligible do
        {:ok, reply_text} = AutoReplyManager.generate_reply(tweet, templates)

        {:ok,
         %{
           should_reply: true,
           reason: to_string(reason),
           reply_text: reply_text
         }}
      else
        {:ok,
         %{
           should_reply: false,
           reason: to_string(reason),
           reply_text: nil
         }}
      end
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters: expected tweet"}
end
