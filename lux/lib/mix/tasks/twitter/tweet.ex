defmodule Mix.Tasks.Twitter.Tweet do
  @moduledoc """
  Send a tweet using the Twitter API.

  ## Usage

      mix twitter.tweet "Hello, world from Lux!"

  Or to reply to another tweet:

      mix twitter.tweet "This is a reply" --reply-to 1234567890

  """

  use Mix.Task
  alias Lux.Integrations.Twitter.Client
  require Logger

  @shortdoc "Send a tweet using the Twitter API"

  @impl Mix.Task
  def run(args) do
    # Start the application to load configuration
    Mix.Task.run("app.start")

    # Parse command line arguments
    {opts, tweet_text_parts, _} = OptionParser.parse(args,
      strict: [
        reply_to: :string,
        help: :boolean
      ],
      aliases: [
        r: :reply_to,
        h: :help
      ]
    )

    # Show help if requested or no text provided
    if opts[:help] || Enum.empty?(tweet_text_parts) do
      print_help()
      System.halt(0)
    end

    # Process the tweet
    process_tweet(tweet_text_parts, opts)
  end

  defp process_tweet(tweet_text_parts, opts) do
    # Join all parts of the tweet text
    tweet_text = Enum.join(tweet_text_parts, " ")

    # Validate the tweet
    validate_tweet_text!(tweet_text)

    # Prepare the tweet payload
    payload = build_tweet_payload(tweet_text, opts)

    # Send the tweet
    send_tweet(tweet_text, payload)
  end

  defp validate_tweet_text!(tweet_text) do
    cond do
      String.length(tweet_text) > 280 ->
        Mix.shell().error("Tweet is too long (max 280 characters)")
        System.halt(1)
      String.length(tweet_text) == 0 ->
        Mix.shell().error("Tweet text cannot be empty")
        System.halt(1)
      true ->
        :ok
    end
  end

  defp build_tweet_payload(tweet_text, opts) do
    # Basic payload
    payload = %{text: tweet_text}

    # Add reply_to if provided
    case opts[:reply_to] do
      nil -> payload
      reply_id -> Map.put(payload, :reply, %{in_reply_to_tweet_id: reply_id})
    end
  end

  defp send_tweet(tweet_text, payload) do
    Mix.shell().info("Sending tweet: \"#{tweet_text}\"")

    case Client.request(:post, "/tweets", %{json: payload}) do
      {:ok, %{"data" => tweet_data}} ->
        handle_successful_tweet(tweet_data)
      error ->
        handle_tweet_error(error)
    end
  end

  defp handle_successful_tweet(tweet_data) do
    Mix.shell().info("Tweet sent successfully!")
    Mix.shell().info("Tweet ID: #{tweet_data["id"]}")
    Mix.shell().info("View at: https://twitter.com/user/status/#{tweet_data["id"]}")
  end

  defp handle_tweet_error({:error, {status, %{"detail" => detail}}}) do
    Mix.shell().error("Failed to send tweet (HTTP #{status}): #{detail}")
    System.halt(1)
  end

  defp handle_tweet_error({:error, {status, body}}) do
    Mix.shell().error("Failed to send tweet (HTTP #{status}): #{inspect(body)}")
    System.halt(1)
  end

  defp handle_tweet_error({:error, error}) do
    Mix.shell().error("Failed to send tweet: #{inspect(error)}")
    System.halt(1)
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
    Mix.shell().info("\nOptions:")
    Mix.shell().info("  --reply-to, -r ID    Tweet ID to reply to")
    Mix.shell().info("  --help, -h           Show this help")
  end
end
