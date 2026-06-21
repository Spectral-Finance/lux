defmodule Lux.Prisms.Twitter.AutoReplyPrism do
  @moduledoc """
  Prism that checks for new mentions and replies to them using an LLM.
  """

  use Lux.Prism,
    name: "Twitter Auto Reply",
    description: "Checks mentions and auto-replies to them"

  alias Lux.Lenses.Twitter.MentionsLens, as: Mentions
  alias Lux.Lenses.Twitter.GetUserLens, as: GetUser
  alias Lux.Prisms.Twitter.PostTweetPrism, as: PostTweet
  alias Lux.Memory.TwitterProcessedMentions, as: Memory

  require Logger

  def handler(input, agent) do
    # 0. Initialize memory if needed
    _ = Memory.initialize()

    # Determine dry_run status
    dry_run = Map.get(input, :dry_run, true) or agent.config[:dry_run] == true or System.get_env("TWITTER_DRY_RUN") == "true"

    # 1. Fetch mentions
    with {:ok, mentions} <- Mentions.focus(),
         {:ok, user} <- GetUser.focus() do
      
      # 2. Iterate and reply
      results = 
        mentions
        |> Enum.reject(fn mention -> Memory.processed?(mention.id) end)
        |> Enum.filter(fn mention -> should_reply?(mention, agent) end)
        |> Enum.map(fn mention ->
          Logger.info("Processing mention from #{mention.author_id}: #{mention.text}")
          
          reply_text = generate_reply(agent, mention, user)
          
          case PostTweet.run(%{
            text: reply_text,
            reply_to_tweet_id: mention.id,
            dry_run: dry_run
          }) do
            {:ok, response} -> 
              unless dry_run, do: Memory.mark_as_processed(mention.id)
              {:ok, response}
            {:error, reason} -> 
              Logger.error("Failed to reply to #{mention.id}: #{inspect(reason)}")
              {:error, reason}
          end
        end)
      
      {:ok, %{processed_count: length(results), dry_run: dry_run}}
    else
      {:error, reason} -> 
        Logger.error("AutoReply failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_reply(agent, mention, user) do
    # Use the agent's LLM to generate a reply
    prompt = """
    You are an AI agent on Twitter. Your handle is @#{user["username"]}.
    Someone mentioned you in a tweet:
    "#{mention.text}"
    
    Your goal is: #{agent.goal}
    
    Write a short, engaging, and helpful reply (max 250 chars to be safe).
    Do not include hashtags unless they are very relevant.
    Maintain a professional yet conversational tone.
    """
    
    case Lux.Agent.chat(agent, prompt) do
      {:ok, reply} -> reply
      _ -> "Thanks for reaching out! How can I help you today?"
    end
  end

  defp should_reply?(mention, agent) do
    rules = get_in(agent.config, [:rules]) || %{}
    text = String.downcase(mention.text)

    # 1. Check exclude keywords
    exclude_keywords = rules[:exclude_keywords] || []
    excluded? = Enum.any?(exclude_keywords, fn kw -> String.contains?(text, String.downcase(kw)) end)

    # 2. Check include keywords
    include_keywords = rules[:include_keywords] || []
    included? = 
      if Enum.empty?(include_keywords) do
        true
      else
        Enum.any?(include_keywords, fn kw -> String.contains?(text, String.downcase(kw)) end)
      end

    not excluded? and included?
  end
end
