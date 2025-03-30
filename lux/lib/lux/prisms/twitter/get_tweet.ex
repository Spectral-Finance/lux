defmodule Lux.Prisms.Twitter.GetTweet do
  @moduledoc """
  A prism for retrieving tweets from Twitter.

  This prism provides a simple interface to get tweets using the Twitter API v2. It leverages
  the Twitter API client for making requests and follows a minimalist approach by:

  - Supporting tweet retrieval by ID
  - Optional expansion of tweet fields (e.g., author info, metrics)
  - Passing through Twitter API errors directly for LLM interpretation

  ## Implementation Details

  - Uses Twitter API v2 endpoint: GET /tweets/:id
  - Returns detailed tweet information including expanded fields if requested
  - Preserves original Twitter API errors for better error handling by LLMs

  ## Examples

      # Get a tweet by ID
      iex> GetTweet.handler(%{
      ...>   id: "1234567890",
      ...>   expansions: ["author_id"]
      ...> }, %{name: "Agent"})
      {:ok, %{
        id: "1234567890",
        text: "Hello, Twitter!",
        author: %{id: "987654321", username: "user123"}
      }}

      # Error handling
      iex> GetTweet.handler(%{
      ...>   id: "invalid_id"
      ...> }, %{name: "Agent"})
      {:error, {400, "Invalid tweet ID"}}
  """

  use Lux.Prism,
    name: "Get Tweet",
    description: "Retrieves a tweet from Twitter by ID",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The ID of the tweet to retrieve",
          pattern: "^[0-9]+$"
        },
        expansions: %{
          type: :array,
          description: "Optional fields to expand in the response (e.g., 'author_id', 'referenced_tweets.id')",
          items: %{
            type: :string,
            enum: ["author_id", "referenced_tweets.id", "attachments.media_keys", "entities.mentions.username", "in_reply_to_user_id"]
          }
        }
      },
      required: ["id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The ID of the tweet"
        },
        text: %{
          type: :string,
          description: "The text content of the tweet"
        },
        author: %{
          type: :object,
          description: "Information about the tweet author (if expanded)",
          properties: %{
            id: %{
              type: :string,
              description: "The user ID of the author"
            },
            username: %{
              type: :string,
              description: "The username of the author"
            }
          }
        },
        created_at: %{
          type: :string,
          description: "The creation timestamp of the tweet"
        },
        metrics: %{
          type: :object,
          description: "Engagement metrics for the tweet",
          properties: %{
            retweet_count: %{
              type: :integer,
              description: "Number of retweets"
            },
            like_count: %{
              type: :integer,
              description: "Number of likes"
            },
            reply_count: %{
              type: :integer,
              description: "Number of replies"
            }
          }
        }
      },
      required: ["id", "text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to retrieve a tweet by ID.

  This implementation:
  - Makes a direct request to Twitter API using the Client module
  - Provides expanded fields if requested
  - Returns success/failure responses with detailed tweet information
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, id} <- validate_param(params, :id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} retrieving tweet with ID: #{id}")

      query_params = build_query_params(params)
      query_string = URI.encode_query(query_params)

      handle_tweet_request(id, query_string)
    end
  end

  defp build_query_params(params) do
    # Start with tweet fields
    query_params = [{"tweet.fields", "author_id,created_at,public_metrics,referenced_tweets"}]

    # Add expansions if provided
    query_params = add_expansions(query_params, params)

    # Add user fields if author_id is expanded
    add_user_fields(query_params, params)
  end

  defp add_expansions(query_params, params) do
    case Map.get(params, :expansions) do
      nil -> query_params
      [] -> query_params
      expansions -> [{"expansions", Enum.join(expansions, ",")} | query_params]
    end
  end

  defp add_user_fields(query_params, params) do
    if params[:expansions] && Enum.member?(params[:expansions], "author_id") do
      [{"user.fields", "id,name,username"} | query_params]
    else
      query_params
    end
  end

  defp handle_tweet_request(id, query_string) do
    case Client.request(:get, "/tweets/#{id}?#{query_string}") do
      {:ok, response} ->
        process_successful_response(id, response)
      {:error, error} ->
        handle_error_response(id, error)
    end
  end

  defp process_successful_response(id, response) do
    tweet_data = response["data"]
    includes = response["includes"] || %{}

    # Build the basic result and add optional fields
    result = %{
      id: tweet_data["id"],
      text: tweet_data["text"]
    }
    |> maybe_add_author(tweet_data, includes)
    |> maybe_add_created_at(tweet_data)
    |> maybe_add_metrics(tweet_data)

    Logger.info("Successfully retrieved tweet with ID: #{id}")
    {:ok, result}
  end

  defp maybe_add_author(result, tweet_data, includes) do
    author = extract_author(tweet_data["author_id"], includes["users"])
    if author, do: Map.put(result, :author, author), else: result
  end

  defp extract_author(nil, _), do: nil
  defp extract_author(_, nil), do: nil
  defp extract_author(author_id, users) do
    author_user = Enum.find(users, fn user -> user["id"] == author_id end)
    if author_user do
      %{
        id: author_user["id"],
        username: author_user["username"],
        name: author_user["name"]
      }
    end
  end

  defp maybe_add_created_at(result, tweet_data) do
    if Map.has_key?(tweet_data, "created_at") do
      Map.put(result, :created_at, tweet_data["created_at"])
    else
      result
    end
  end

  defp maybe_add_metrics(result, tweet_data) do
    metrics = extract_metrics(tweet_data["public_metrics"])
    if metrics, do: Map.put(result, :metrics, metrics), else: result
  end

  defp extract_metrics(nil), do: nil
  defp extract_metrics(metrics) do
    %{
      retweet_count: metrics["retweet_count"],
      like_count: metrics["like_count"],
      reply_count: metrics["reply_count"]
    }
  end

  defp handle_error_response(id, {status, %{"detail" => detail}}) do
    error = {status, detail}
    Logger.error("Failed to retrieve tweet #{id}: #{inspect(error)}")
    {:error, error}
  end

  defp handle_error_response(id, {status, body}) do
    error = {status, body}
    Logger.error("Failed to retrieve tweet #{id}: #{inspect(error)}")
    {:error, error}
  end

  defp handle_error_response(id, error) do
    Logger.error("Failed to retrieve tweet #{id}: #{inspect(error)}")
    {:error, error}
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
