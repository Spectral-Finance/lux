defmodule Lux.Lenses.Twitter.ContentCurationLens do
  @moduledoc """
  Lens for discovering and curating trending content for Twitter engagement.

  Searches Twitter for trending topics, popular tweets, and relevant content
  based on keywords, hashtags, and user interests. Supports filtering by
  engagement thresholds and content type.

  ## Example

      iex> Lux.Lenses.Twitter.ContentCurationLens.focus(%{keywords: ["elixir", "web3"], min_engagement: 100})
      {:ok, %{trending: [...], curated: [...], topics: [...]}}
  """

  use Lux.Lens,
    name: "Twitter Content Curation",
    description: "Discovers and curates trending Twitter content based on keywords, hashtags, and engagement metrics",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :api_key,
      key: &System.get_env("TWITTER_BEARER_TOKEN")
    },
    schema: %{
      type: :object,
      properties: %{
        keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Keywords or phrases to search for"
        },
        hashtags: %{
          type: :array,
          items: %{type: :string},
          description: "Hashtags to search for (without #)"
        },
        min_engagement: %{
          type: :integer,
          description: "Minimum engagement threshold (likes + retweets + replies)",
          default: 0
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results to return (10-100)",
          default: 20
        },
        language: %{
          type: :string,
          description: "ISO 639-1 language code to filter results",
          default: "en"
        },
        content_type: %{
          type: :string,
          description: "Type of content to prioritize",
          enum: ["any", "original", "replies", "links", "media"],
          default: "any"
        },
        exclude_retweets: %{
          type: :boolean,
          description: "Whether to exclude retweets from results",
          default: true
        },
        time_range: %{
          type: :string,
          description: "Time range for search",
          enum: ["recent", "day", "week", "month"],
          default: "recent"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        trending: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              text: %{type: :string},
              author: %{type: :string},
              engagement_score: %{type: :number},
              hashtags: %{type: :array},
              mentions: %{type: :array}
            }
          }
        },
        curated: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              text: %{type: :string},
              author: %{type: :string},
              relevance_score: %{type: :number},
              content_type: %{type: :string},
              suggested_action: %{type: :string}
            }
          }
        },
        topics: %{
          type: :array,
          items: %{type: :string}
        },
        search_metadata: %{
          type: :object,
          properties: %{
            total_results: %{type: :integer},
            query: %{type: :string},
            search_time: %{type: :string}
          }
        }
      }
    }

  @doc """
  Discovers and curates trending content based on search criteria.
  """
  def focus(params) do
    keywords = Map.get(params, :keywords, params["keywords"] || [])
    hashtags = Map.get(params, :hashtags, params["hashtags"] || [])
    min_engagement = Map.get(params, :min_engagement, params["min_engagement"] || 0)
    max_results = Map.get(params, :max_results, params["max_results"] || 20)
    language = Map.get(params, :language, params["language"] || "en")
    content_type = Map.get(params, :content_type, params["content_type"] || "any")
    exclude_retweets = Map.get(params, :exclude_retweets, params["exclude_retweets"] || true)
    time_range = Map.get(params, :time_range, params["time_range"] || "recent")

    # Build search query
    query = build_search_query(keywords, hashtags, content_type, exclude_retweets)

    # Search for content
    search_results = search_twitter(query, max_results, language)

    # Score and rank results
    scored_results = score_content(search_results, keywords, hashtags)

    # Categorize content
    trending = get_trending_content(scored_results, min_engagement)
    curated = get_curated_content(scored_results, keywords)
    topics = extract_topics(scored_results, hashtags)

    data = %{
      trending: trending,
      curated: curated,
      topics: topics,
      search_metadata: %{
        total_results: length(search_results),
        query: query,
        search_time: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }

    {:ok, data}
  end

  defp build_search_query(keywords, hashtags, content_type, exclude_retweets) do
    parts = []

    # Add keywords
    parts = if length(keywords) > 0 do
      keyword_query = keywords
      |> Enum.map(fn kw -> "\"#{kw}\"" end)
      |> Enum.join(" OR ")
      [keyword_query | parts]
    else
      parts
    end

    # Add hashtags
    parts = if length(hashtags) > 0 do
      hashtag_query = hashtags
      |> Enum.map(fn tag -> "##{tag}" end)
      |> Enum.join(" OR ")
      [hashtag_query | parts]
    else
      parts
    end

    # Add content type filters
    parts = case content_type do
      "original" -> ["-is:retweet" | parts]
      "replies" -> ["is:reply" | parts]
      "links" -> ["url_links" | parts]
      "media" -> ["has:media" | parts]
      _ -> parts
    end

    # Add exclude retweets
    parts = if exclude_retweets do
      ["-is:retweet" | parts]
    else
      parts
    end

    parts
    |> Enum.reverse()
    |> Enum.join(" ")
    |> String.trim()
  end

  defp search_twitter(query, max_results, language) do
    if query == "" do
      []
    else
      query_params = %{
        "query" => query,
        "max_results" => max_results,
        "tweet.fields" => "public_metrics,author_id,created_at,entities,lang,context_annotations",
        "expansions" => "author_id",
        "user.fields" => "name,username,public_metrics",
        "lang" => language
      }

      case Req.get(@url, params: query_params, headers: get_headers()) do
        {:ok, %{status: 200, body: body}} ->
          Map.get(body, "data", [])

        _ ->
          []
      end
    end
  end

  defp get_headers do
    [{"Content-Type", "application/json"}]
  end

  defp score_content(tweets, keywords, hashtags) do
    Enum.map(tweets, fn tweet ->
      text = tweet["text"] || ""
      text_lower = String.downcase(text)
      public_metrics = tweet["public_metrics"] || %{}

      # Calculate relevance score based on keyword matches
      keyword_score = Enum.reduce(keywords, 0, fn kw, acc ->
        if String.contains?(text_lower, String.downcase(kw)), do: acc + 1, else: acc
      end)

      # Calculate hashtag matches
      hashtag_score = Enum.reduce(hashtags, 0, fn tag, acc ->
        if String.contains?(text_lower, String.downcase("##{tag}")), do: acc + 1, else: acc
      end)

      # Calculate engagement score
      likes = Map.get(public_metrics, "like_count", 0)
      retweets = Map.get(public_metrics, "retweet_count", 0)
      replies = Map.get(public_metrics, "reply_count", 0)
      engagement_score = likes * 1 + retweets * 2 + replies * 3

      # Combined relevance score
      relevance_score = keyword_score * 10 + hashtag_score * 5 + engagement_score

      %{
        tweet: tweet,
        relevance_score: relevance_score,
        engagement_score: engagement_score,
        keyword_matches: keyword_score,
        hashtag_matches: hashtag_score
      }
    end)
    |> Enum.sort_by(fn r -> r.relevance_score end, :desc)
  end

  defp get_trending_content(scored_results, min_engagement) do
    scored_results
    |> Enum.filter(fn r -> r.engagement_score >= min_engagement end)
    |> Enum.take(10)
    |> Enum.map(fn r ->
      tweet = r.tweet
      entities = tweet["entities"] || %{}
      hashtags = Enum.map(entities["hashtags"] || [], & &1["text"])
      mentions = Enum.map(entities["mentions"] || [], & &1["username"])

      %{
        id: tweet["id"],
        text: tweet["text"],
        author: tweet["author_id"],
        engagement_score: r.engagement_score,
        hashtags: hashtags,
        mentions: mentions
      }
    end)
  end

  defp get_curated_content(scored_results, keywords) do
    scored_results
    |> Enum.take(10)
    |> Enum.map(fn r ->
      tweet = r.tweet
      content_type = classify_content(tweet)
      suggested_action = suggest_action(r, keywords)

      %{
        id: tweet["id"],
        text: tweet["text"],
        author: tweet["author_id"],
        relevance_score: r.relevance_score,
        content_type: content_type,
        suggested_action: suggested_action
      }
    end)
  end

  defp classify_content(tweet) do
    text = tweet["text"] || ""
    entities = tweet["entities"] || %{}

    cond do
      Map.has_key?(entities, "urls") and length(entities["urls"] || []) > 0 -> "link"
      Map.has_key?(entities, "media") and length(entities["media"] || []) > 0 -> "media"
      String.contains?(text, "RT @") -> "retweet"
      true -> "original"
    end
  end

  defp suggest_action(%{keyword_matches: km, relevance_score: rs}, _keywords) do
    cond do
      rs > 50 -> "high_priority_engagement"
      km > 0 -> "consider_engagement"
      true -> "monitor"
    end
  end

  defp extract_topics(scored_results, hashtags) do
    all_hashtags = Enum.flat_map(scored_results, fn r ->
      entities = r.tweet["entities"] || %{}
      Enum.map(entities["hashtags"] || [], & &1["text"])
    end)

    # Count and rank hashtags
    all_hashtags
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_tag, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {tag, _count} -> tag end)
    |> Enum.concat(hashtags)
    |> Enum.uniq()
  end
end
