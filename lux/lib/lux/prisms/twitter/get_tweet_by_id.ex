defmodule Lux.Prisms.Twitter.GetTweetById do
  @moduledoc """
  A prism for fetching a tweet by its ID.

  ## Examples

      iex> GetTweetById.handler(%{tweet_id: "123456"}, %{name: "Agent"})
      {:ok, %{id: "123456", text: "Hello, world!", author_id: "789"}}
  """

  use Lux.Prism,
    name: "Get Tweet By ID",
    description: "Fetches a tweet's details by its tweet ID",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to fetch"
        },
        expansions: %{
          type: :string,
          description: "Comma-separated list of field expansions"
        },
        tweet.fields: %{
          type: :string,
          description: "Comma-separated list of tweet fields to return"
        },
        media.fields: %{
          type: :string,
          description: "Comma-separated list of media fields"
        },
        place.fields: %{
          type: :string,
          description: "Comma-separated list of place fields"
        },
        poll.fields: %{
          type: :string,
          description: "Comma-separated list of poll fields"
        },
        author_fields: %{
          type: :string,
          description: "Comma-separated list of author fields"
        }
      },
      required: ["tweet_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The tweet ID"},
        text: %{type: :string, description: "The tweet text"},
        author_id: %{type: :string, description: "ID of the tweet author"},
        created_at: %{type: :string, description: "ISO 8601 timestamp"}
      },
      required: ["id", "text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles fetching a tweet by ID.

  Returns {:ok, %{id, text, author_id, ...}} on success.
  """
  def handler(params, agent) do
    with {:ok, tweet_id} <- validate_param(params, :tweet_id),
         {:ok, expansions} <- validate_optional_string(params, :expansions),
         {:ok, fields} <- validate_optional_string(params, "tweet.fields") do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching tweet #{tweet_id}")

      url = build_url(tweet_id, expansions, fields)

      case Client.request(:get, url) do
        {:ok, %{"data" => tweet}} ->
          Logger.info("Successfully fetched tweet #{tweet_id}")
          {:ok, Map.take(tweet, ["id", "text", "author_id", "created_at", "public_metrics"])}

        {:error, {status, %{"errors" => errors}}} when is_list(errors) ->
          error_msg = List.first(errors) |> Map.get("message", "Tweet not found")
          Logger.error("Failed to fetch tweet: #{error_msg}")
          {:error, {status, error_msg}}

        {:error, error} ->
          Logger.error("Failed to fetch tweet: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp build_url(tweet_id, nil, nil), do: "/tweets/#{tweet_id}"

  defp build_url(tweet_id, expansions, fields) do
    params = ["id" => tweet_id]
    params = if expansions, do: [expansions: expansions] ++ params, else: params
    params = if fields, do: [{"tweet.fields"} => fields] ++ params, else: params

    qs = params |> Enum.map_join("&", fn {k, v} -> "#{k}=#{v}" end)
    "/tweets/#{tweet_id}?#{qs}"
  end

  defp build_url(tweet_id, expansions, nil), do: "/tweets/#{tweet_id}?expansions=#{expansions}"
  defp build_url(tweet_id, nil, fields), do: "/tweets/#{tweet_id}?tweet.fields=#{fields}"

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_optional_string(params, key, default \\ "") do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      :error -> {:ok, default}
      _ -> {:error, "Invalid #{key}"}
    end
  end
end
