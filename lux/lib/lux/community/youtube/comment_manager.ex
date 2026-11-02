defmodule Lux.Community.YouTube.CommentManager do
  @moduledoc """
  Manages YouTube comment threads, replies, and moderation state transitions.

  Provides capabilities for:
  - Ingestion and normalization of YouTube Data API v3 comment threads
  - Filtering by moderation status (:published, :held_for_review, :likely_spam)
  - Sorting by engagement (likes, replies) and recency
  - Drafting and appending replies to comment threads
  - State changes (pinning, approving, rejecting, flagging)
  """

  @type comment :: %{
          id: String.t(),
          video_id: String.t(),
          author_name: String.t(),
          author_channel_id: String.t(),
          text: String.t(),
          published_at: DateTime.t() | String.t(),
          like_count: non_neg_integer(),
          reply_count: non_neg_integer(),
          status: :published | :held_for_review | :likely_spam | :rejected,
          is_pinned: boolean(),
          replies: list(map())
        }

  @doc """
  Normalizes raw YouTube Data API v3 comment thread payloads into structured comment maps.
  """
  @spec normalize_comment_thread(map()) :: comment()
  def normalize_comment_thread(raw) when is_map(raw) do
    snippet = get_field(raw, :snippet, %{})
    top_level = get_field(snippet, :topLevelComment, %{})
    top_snippet = get_field(top_level, :snippet, %{})

    %{
      id: get_field(raw, :id, "comment_" <> Integer.to_string(:erlang.phash2(raw))),
      video_id: get_field(top_snippet, :videoId, get_field(snippet, :videoId, "")),
      author_name: get_field(top_snippet, :authorDisplayName, "Anonymous"),
      author_channel_id: extract_author_channel_id(top_snippet),
      text: get_field(top_snippet, :textDisplay, get_field(top_snippet, :textOriginal, "")),
      published_at: get_field(top_snippet, :publishedAt, DateTime.utc_now() |> DateTime.to_iso8601()),
      like_count: get_field(top_snippet, :likeCount, 0),
      reply_count: get_field(snippet, :totalReplyCount, 0),
      status: parse_moderation_status(get_field(top_snippet, :moderationStatus, "published")),
      is_pinned: get_field(top_snippet, :isPinned, false),
      replies: extract_replies(raw)
    }
  end

  @doc """
  Filters a list of comments by moderation status and optional search keyword.
  """
  @spec filter_comments(list(comment()), keyword()) :: list(comment())
  def filter_comments(comments, opts \\ []) do
    status_filter = Keyword.get(opts, :status)
    video_filter = Keyword.get(opts, :video_id)
    search_query = Keyword.get(opts, :search)

    comments
    |> Enum.filter(fn c -> is_nil(status_filter) or c.status == status_filter end)
    |> Enum.filter(fn c -> is_nil(video_filter) or c.video_id == video_filter end)
    |> Enum.filter(fn c ->
      if is_nil(search_query) or search_query == "" do
        true
      else
        String.contains?(String.downcase(c.text), String.downcase(search_query))
      end
    end)
  end

  @doc """
  Sorts comments by popularity (:likes), discussion depth (:replies), or recency (:recent).
  """
  @spec sort_comments(list(comment()), :likes | :replies | :recent) :: list(comment())
  def sort_comments(comments, sort_by \\ :likes) do
    case sort_by do
      :likes ->
        Enum.sort_by(comments, & &1.like_count, :desc)

      :replies ->
        Enum.sort_by(comments, & &1.reply_count, :desc)

      :recent ->
        Enum.sort_by(comments, & &1.published_at, :desc)
    end
  end

  @doc """
  Appends an automated or manual reply to a comment thread.
  """
  @spec add_reply(comment(), String.t(), String.t()) :: comment()
  def add_reply(comment, reply_text, author \\ "Channel Host") do
    reply = %{
      id: "reply_" <> Integer.to_string(:erlang.system_time(:millisecond)),
      parent_id: comment.id,
      author_name: author,
      text: reply_text,
      published_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      like_count: 0
    }

    %{comment | replies: comment.replies ++ [reply], reply_count: comment.reply_count + 1}
  end

  @doc """
  Updates moderation status of a comment.
  """
  @spec update_status(comment(), :published | :held_for_review | :likely_spam | :rejected) :: comment()
  def update_status(comment, new_status) when new_status in [:published, :held_for_review, :likely_spam, :rejected] do
    %{comment | status: new_status}
  end

  @doc """
  Toggles the pinned status of a comment.
  """
  @spec toggle_pin(comment()) :: comment()
  def toggle_pin(comment) do
    %{comment | is_pinned: !comment.is_pinned}
  end

  defp parse_moderation_status("heldForReview"), do: :held_for_review
  defp parse_moderation_status("likelySpam"), do: :likely_spam
  defp parse_moderation_status("rejected"), do: :rejected
  defp parse_moderation_status(_), do: :published

  defp extract_author_channel_id(snippet) do
    case get_field(snippet, :authorChannelId, nil) do
      %{"value" => id} -> id
      %{value: id} -> id
      id when is_binary(id) -> id
      _ -> "channel_unknown"
    end
  end

  defp extract_replies(raw) do
    replies_data = get_field(raw, :replies, %{})
    comments_list = get_field(replies_data, :comments, [])

    Enum.map(comments_list, fn r ->
      snip = get_field(r, :snippet, %{})
      %{
        id: get_field(r, :id, "reply_sub"),
        author_name: get_field(snip, :authorDisplayName, "User"),
        text: get_field(snip, :textDisplay, ""),
        published_at: get_field(snip, :publishedAt, "")
      }
    end)
  end

  defp get_field(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key), default)
  end

  defp get_field(_, _, default), do: default
end
