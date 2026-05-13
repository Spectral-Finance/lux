defmodule Lux.Integrations.YouTube.LiveStreaming do
  @moduledoc """
  YouTube live broadcast, stream, and live-chat helpers.
  """

  alias Lux.Integrations.YouTube.Client

  @broadcast_parts "snippet,status,contentDetails"
  @stream_parts "snippet,cdn,status"
  @chat_parts "snippet,authorDetails"

  @doc """
  Creates a YouTube live broadcast.
  """
  @spec create_broadcast(map(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def create_broadcast(attrs, opts \\ %{}) do
    Client.request(:post, "/liveBroadcasts", put_request(opts, %{
      params: %{part: @broadcast_parts},
      json: broadcast_body(attrs)
    }))
  end

  @doc """
  Creates a YouTube live stream ingestion endpoint.
  """
  @spec create_stream(map(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def create_stream(attrs, opts \\ %{}) do
    Client.request(:post, "/liveStreams", put_request(opts, %{
      params: %{part: @stream_parts},
      json: stream_body(attrs)
    }))
  end

  @doc """
  Binds an existing broadcast to a stream.
  """
  @spec bind_broadcast(String.t(), String.t(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def bind_broadcast(broadcast_id, stream_id, opts \\ %{}) do
    Client.request(:post, "/liveBroadcasts/bind", put_request(opts, %{
      params: %{part: "id,contentDetails", id: broadcast_id, streamId: stream_id}
    }))
  end

  @doc """
  Transitions a broadcast between `testing`, `live`, and `complete`.
  """
  @spec transition_broadcast(String.t(), String.t(), map() | keyword()) ::
          {:ok, map()} | {:error, term()}
  def transition_broadcast(broadcast_id, status, opts \\ %{})
      when status in ["testing", "live", "complete"] do
    Client.request(:post, "/liveBroadcasts/transition", put_request(opts, %{
      params: %{part: "id,status", id: broadcast_id, broadcastStatus: status}
    }))
  end

  @doc """
  Lists live-chat messages for a broadcast chat.
  """
  @spec list_chat_messages(String.t(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def list_chat_messages(live_chat_id, opts \\ %{}) do
    Client.request(:get, "/liveChat/messages", put_request(opts, %{
      params: %{part: @chat_parts, liveChatId: live_chat_id}
    }))
  end

  @doc """
  Sends a text message to a live chat.
  """
  @spec send_chat_message(String.t(), String.t(), map() | keyword()) :: {:ok, map()} | {:error, term()}
  def send_chat_message(live_chat_id, text, opts \\ %{}) do
    Client.request(:post, "/liveChat/messages", put_request(opts, %{
      params: %{part: "snippet"},
      json: %{
        snippet: %{
          liveChatId: live_chat_id,
          type: "textMessageEvent",
          textMessageDetails: %{messageText: text}
        }
      }
    }))
  end

  defp broadcast_body(attrs) do
    %{
      snippet: %{
        title: required!(attrs, :title),
        scheduledStartTime: required!(attrs, :scheduled_start_time),
        description: attrs[:description]
      },
      status: %{
        privacyStatus: attrs[:privacy_status] || "private",
        selfDeclaredMadeForKids: Map.get(attrs, :self_declared_made_for_kids, false)
      },
      contentDetails: %{
        enableAutoStart: Map.get(attrs, :enable_auto_start, false),
        enableAutoStop: Map.get(attrs, :enable_auto_stop, true)
      }
    }
    |> drop_nil_values()
  end

  defp stream_body(attrs) do
    %{
      snippet: %{title: required!(attrs, :title), description: attrs[:description]},
      cdn: %{
        ingestionType: attrs[:ingestion_type] || "rtmp",
        resolution: attrs[:resolution] || "1080p",
        frameRate: attrs[:frame_rate] || "30fps"
      }
    }
    |> drop_nil_values()
  end

  defp put_request(opts, overrides) when is_list(opts), do: opts |> Map.new() |> put_request(overrides)

  defp put_request(opts, overrides) do
    opts
    |> Map.new()
    |> Map.merge(overrides, fn
      :params, left, right -> Map.merge(Map.new(left), right)
      _key, _left, right -> right
    end)
  end

  defp required!(attrs, key), do: attrs[key] || raise ArgumentError, "#{key} is required"

  defp drop_nil_values(map) do
    map
    |> Enum.map(fn
      {key, value} when is_map(value) -> {key, drop_nil_values(value)}
      pair -> pair
    end)
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
