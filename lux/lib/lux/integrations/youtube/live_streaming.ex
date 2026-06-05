defmodule Lux.Integrations.YouTube.LiveStreaming do
  @moduledoc """
  Deterministic YouTube live-streaming workflow planning.

  This module builds auditable YouTube Data API v3 request plans for OAuth,
  uploads, live broadcasts, live streams, live chat, health monitoring, and
  broadcast transitions. The returned plans are safe to test without credentials
  and can be executed by a credentialed adapter later.
  """

  alias Lux.Integrations.YouTube.Client

  @allowed_transitions %{
    "created" => ["testing", "live"],
    "ready" => ["testing", "live"],
    "testing" => ["live", "complete"],
    "live" => ["complete"]
  }

  @doc """
  Builds a complete dry-run workflow for YouTube core integration and live setup.
  """
  @spec plan_broadcast_workflow(map()) :: {:ok, map()} | {:error, String.t()}
  def plan_broadcast_workflow(params) when is_map(params) do
    with {:ok, title} <- required(params, :title),
         {:ok, scheduled_start_time} <- required(params, :scheduled_start_time) do
      workflow = %{
        mode: :dry_run,
        oauth: oauth_plan(params),
        channel: channel_request(params),
        upload: upload_plan(params),
        broadcast: broadcast_plan(params, title, scheduled_start_time),
        stream: stream_plan(params),
        bind: bind_plan(params),
        live_chat: live_chat_plan(params),
        health_monitor: health_monitor_plan(params),
        transition: transition_plan(params),
        quality_controls: quality_controls(params),
        execution_boundary: %{
          live_side_effects: false,
          note:
            "Plans are deterministic request envelopes. A caller must supply OAuth credentials and explicitly execute requests."
        }
      }

      {:ok, workflow}
    end
  end

  @doc """
  Normalizes YouTube live chat messages and classifies moderation work.
  """
  @spec analyze_chat_messages([map()], map()) :: map()
  def analyze_chat_messages(messages, opts \\ %{}) do
    blocked_terms = params_list(opts, :blocked_terms)
    highlight_terms = params_list(opts, :highlight_terms)

    normalized =
      Enum.map(messages, fn message ->
        text = get(message, :text, get(message, :display_message, ""))
        lower = String.downcase(to_string(text))

        flags =
          []
          |> maybe_flag(:blocked_term, contains_any?(lower, blocked_terms))
          |> maybe_flag(:highlight, contains_any?(lower, highlight_terms))
          |> maybe_flag(:link, String.contains?(lower, "http://") or String.contains?(lower, "https://"))
          |> maybe_flag(:empty, String.trim(to_string(text)) == "")

        %{
          id: get(message, :id, nil),
          author: get(message, :author, "unknown"),
          text: text,
          flags: flags,
          action: moderation_action(flags)
        }
      end)

    %{
      messages: normalized,
      action_counts: Enum.frequencies_by(normalized, & &1.action),
      requires_review: Enum.any?(normalized, &(&1.action in [:hold, :remove, :highlight]))
    }
  end

  @doc """
  Classifies stream health from YouTube health status and local metric samples.
  """
  @spec health_snapshot(map()) :: map()
  def health_snapshot(params) do
    status = get(params, :status, "unknown")
    bitrate = numeric(get(params, :bitrate_kbps, 0))
    dropped_frames = numeric(get(params, :dropped_frames, 0))
    latency_ms = numeric(get(params, :latency_ms, 0))

    issues =
      []
      |> maybe_issue("youtube_status_#{status}", status in ["bad", "noData", "error"])
      |> maybe_issue("low_bitrate", bitrate > 0 and bitrate < numeric(get(params, :min_bitrate_kbps, 2_500)))
      |> maybe_issue("dropped_frames", dropped_frames > numeric(get(params, :max_dropped_frames, 30)))
      |> maybe_issue("high_latency", latency_ms > numeric(get(params, :max_latency_ms, 10_000)))

    %{
      status: if(issues == [], do: :healthy, else: :attention_required),
      youtube_status: status,
      metrics: %{
        bitrate_kbps: bitrate,
        dropped_frames: dropped_frames,
        latency_ms: latency_ms
      },
      issues: issues,
      poll_interval_seconds: numeric(get(params, :poll_interval_seconds, 30))
    }
  end

  @doc """
  Builds a safe transition plan for YouTube live broadcast lifecycle changes.
  """
  @spec transition_plan(map()) :: map()
  def transition_plan(params) do
    current = get(params, :current_life_cycle_status, "ready")
    target = get(params, :target_life_cycle_status, "testing")
    allowed = Map.get(@allowed_transitions, current, [])

    case required_values(params, [:broadcast_id]) do
      {:ok, %{broadcast_id: broadcast_id}} ->
        %{
          allowed: target in allowed,
          current_life_cycle_status: current,
          target_life_cycle_status: target,
          request:
            Client.build_request(:post, "/liveBroadcasts/transition", %{
              access_token: get(params, :access_token, nil),
              query: %{broadcast_status: target, id: broadcast_id, part: "status"}
            }),
          guardrails: transition_guardrails(current, target, allowed)
        }

      {:error, error, missing} ->
        %{
          allowed: false,
          current_life_cycle_status: current,
          target_life_cycle_status: target,
          request: guarded_request(:transition_broadcast, error, missing),
          guardrails: [error | transition_guardrails(current, target, allowed)]
        }
    end
  end

  defp oauth_plan(params) do
    %{
      scopes: Client.default_scopes(),
      authorization_url:
        maybe_authorization_url(params, [:client_id, :redirect_uri]),
      token_exchange:
        maybe_token_request(:authorization_code, params, [:client_id, :client_secret, :code, :redirect_uri]),
      refresh:
        maybe_token_request(:refresh_token, params, [:client_id, :client_secret, :refresh_token])
    }
  end

  defp channel_request(params) do
    Client.build_request(:get, "/channels", %{
      access_token: get(params, :access_token, nil),
      query: %{part: "snippet,contentDetails,statistics", mine: true}
    })
  end

  defp upload_plan(params) do
    %{
      resumable_start:
        Client.resumable_upload_request(%{
          access_token: get(params, :access_token, nil),
          title: get(params, :video_title, get(params, :title, "Untitled live archive")),
          description: get(params, :video_description, ""),
          tags: params_list(params, :tags),
          privacy_status: get(params, :privacy_status, "private"),
          category_id: get(params, :category_id, "22"),
          content_type: get(params, :content_type, "video/mp4"),
          content_length: get(params, :content_length, 0)
        }),
      upload_session: %{
        source: "Location response header from resumable_start",
        required_parameter: :upload_url,
        note: "Use the returned upload session URL for all chunk and resume requests."
      },
      chunk_upload: chunk_upload_plan(params),
      resume_probe: resume_probe_plan(params),
      status_request:
        guarded_request(params, [:video_id], :video_status, fn %{video_id: video_id} ->
          Client.build_request(:get, "/videos", %{
            access_token: get(params, :access_token, nil),
            query: %{part: "snippet,status,liveStreamingDetails", id: video_id}
          })
        end)
    }
  end

  defp broadcast_plan(params, title, scheduled_start_time) do
    body = %{
      snippet: %{
        title: title,
        description: get(params, :description, ""),
        scheduledStartTime: scheduled_start_time,
        scheduledEndTime: get(params, :scheduled_end_time, nil)
      },
      status: %{
        privacyStatus: get(params, :privacy_status, "private"),
        selfDeclaredMadeForKids: get(params, :made_for_kids, false)
      },
      contentDetails: %{
        enableAutoStart: get(params, :enable_auto_start, false),
        enableAutoStop: get(params, :enable_auto_stop, true),
        enableDvr: get(params, :enable_dvr, true),
        recordFromStart: get(params, :record_from_start, true)
      }
    }

    body = prune_empty_values(body)

    %{
      insert:
        Client.build_request(:post, "/liveBroadcasts", %{
          access_token: get(params, :access_token, nil),
          query: %{part: "snippet,status,contentDetails"},
          json: body
        }),
      list:
        Client.build_request(:get, "/liveBroadcasts", %{
          access_token: get(params, :access_token, nil),
          query: %{part: "snippet,status,contentDetails", broadcast_status: "all", mine: true}
        })
    }
  end

  defp stream_plan(params) do
    body = %{
      snippet: %{title: get(params, :stream_title, get(params, :title, "Lux live stream"))},
      cdn: %{
        frameRate: get(params, :frame_rate, "variable"),
        ingestionType: get(params, :ingestion_type, "rtmp"),
        resolution: get(params, :resolution, "variable")
      }
    }

    %{
      insert:
        Client.build_request(:post, "/liveStreams", %{
          access_token: get(params, :access_token, nil),
          query: %{part: "snippet,cdn,status"},
          json: body
        }),
      status:
        guarded_request(params, [:stream_id], :stream_status, fn %{stream_id: stream_id} ->
          Client.build_request(:get, "/liveStreams", %{
            access_token: get(params, :access_token, nil),
            query: %{part: "snippet,cdn,status", id: stream_id}
          })
        end)
    }
  end

  defp bind_plan(params) do
    guarded_request(params, [:broadcast_id, :stream_id], :bind_broadcast, fn values ->
      %{broadcast_id: broadcast_id, stream_id: stream_id} = values

      Client.build_request(:post, "/liveBroadcasts/bind", %{
        access_token: get(params, :access_token, nil),
        query: %{
          id: broadcast_id,
          stream_id: stream_id,
          part: "id,contentDetails"
        }
      })
    end)
  end

  defp live_chat_plan(params) do
    %{
      list:
        guarded_request(
          params,
          [:live_chat_id],
          :list_live_chat_messages,
          fn %{live_chat_id: chat_id} ->
            Client.build_request(:get, "/liveChat/messages", %{
              access_token: get(params, :access_token, nil),
              query: %{
                live_chat_id: chat_id,
                part: "snippet,authorDetails",
                max_results: get(params, :live_chat_max_results, 200),
                page_token: get(params, :live_chat_page_token, nil)
              }
            })
          end
        ),
      send:
        guarded_request(
          params,
          [:live_chat_id],
          :send_live_chat_message,
          fn %{live_chat_id: chat_id} ->
            Client.build_request(:post, "/liveChat/messages", %{
              access_token: get(params, :access_token, nil),
              query: %{part: "snippet"},
              json: %{
                snippet: %{
                  liveChatId: chat_id,
                  type: "textMessageEvent",
                  textMessageDetails: %{messageText: get(params, :chat_message, "")}
                }
              }
            })
          end
        ),
      pagination: %{
        next_page_token: :from_youtube_response,
        polling_interval_millis: :from_youtube_response
      },
      moderation: analyze_chat_messages(get(params, :chat_messages, []), params)
    }
  end

  defp health_monitor_plan(params) do
    %{
      request:
        guarded_request(params, [:stream_id], :stream_health, fn %{stream_id: stream_id} ->
          Client.build_request(:get, "/liveStreams", %{
            access_token: get(params, :access_token, nil),
            query: %{part: "status", id: stream_id}
          })
        end),
      snapshot: health_snapshot(get(params, :health, %{}))
    }
  end

  defp quality_controls(params) do
    %{
      primary_stream: %{
        stream_id: get(params, :stream_id, nil),
        resolution: get(params, :resolution, "variable"),
        frame_rate: get(params, :frame_rate, "variable")
      },
      backup_streams:
        get(params, :backup_streams, [])
        |> Enum.map(fn stream ->
          %{
            stream_id: get(stream, :stream_id, nil),
            resolution: get(stream, :resolution, "variable"),
            frame_rate: get(stream, :frame_rate, "variable"),
            ready: get(stream, :ready, false)
          }
        end),
      failover_ready: Enum.any?(get(params, :backup_streams, []), &get(&1, :ready, false)),
      checks: [
        "confirm OAuth token scope before executing mutating calls",
        "poll stream health before transition to live",
        "review live chat moderation actions before sending or removing messages",
        "keep backup stream ready before public broadcasts"
      ]
    }
  end

  defp maybe_authorization_url(params, keys) do
    if all_present?(params, keys), do: Client.authorization_url(params), else: nil
  end

  defp maybe_token_request(type, params, keys) do
    if all_present?(params, keys), do: Client.token_request(type, params), else: nil
  end

  defp chunk_upload_plan(params) do
    with {:ok, values} <- required_values(params, [:upload_url, :content_length]),
         {:ok, content_length} <- positive_integer(values.content_length, :content_length) do
      range_start = integer(get(params, :chunk_start, 0))

      Client.resumable_chunk_request(%{
        access_token: get(params, :access_token, nil),
        upload_url: values.upload_url,
        content_type: get(params, :content_type, "video/mp4"),
        content_length: content_length,
        range_start: range_start,
        range_end: get(params, :chunk_end, range_start + content_length - 1),
        total_length: get(params, :total_length, content_length)
      })
    else
      {:error, error, missing} when is_list(missing) ->
        guarded_request(:upload_video_chunk, error, missing)

      {:error, error, key} -> guarded_request(:upload_video_chunk, error, [key])
    end
  end

  defp resume_probe_plan(params) do
    with {:ok, values} <- required_values(params, [:upload_url, :total_length]),
         {:ok, total_length} <- positive_integer(values.total_length, :total_length) do
      Client.resumable_resume_request(%{
        access_token: get(params, :access_token, nil),
        upload_url: values.upload_url,
        total_length: total_length
      })
    else
      {:error, error, missing} when is_list(missing) ->
        guarded_request(:resume_upload_session, error, missing)

      {:error, error, key} -> guarded_request(:resume_upload_session, error, [key])
    end
  end

  defp guarded_request(params, keys, operation, fun) do
    case required_values(params, keys) do
      {:ok, values} -> fun.(values)
      {:error, error, missing} -> guarded_request(operation, error, missing)
    end
  end

  defp guarded_request(operation, error, missing) do
    %{
      operation: operation,
      executable: false,
      error: error,
      required_parameters: missing
    }
  end

  defp all_present?(params, keys) do
    Enum.all?(keys, fn key ->
      value = get(params, key, nil)
      not is_nil(value) and value != ""
    end)
  end

  defp transition_guardrails(current, target, allowed) do
    cond do
      target in allowed ->
        ["poll liveStreams.status before transition", "confirm broadcast contentDetails are bound to a stream"]

      current == "complete" ->
        ["completed broadcasts cannot be transitioned again"]

      true ->
        ["invalid transition #{current} -> #{target}; allowed targets are #{Enum.join(allowed, ", ")}"]
    end
  end

  defp required(params, key) do
    case get(params, key, nil) do
      nil -> {:error, "Missing required YouTube live parameter #{key}"}
      "" -> {:error, "Missing required YouTube live parameter #{key}"}
      value -> {:ok, value}
    end
  end

  defp required_values(params, keys) do
    missing = Enum.filter(keys, &missing_param?(params, &1))

    case missing do
      [] -> {:ok, Map.new(keys, fn key -> {key, get(params, key, nil)} end)}
      [key] -> {:error, "Missing required YouTube live parameter #{key}", [key]}
      keys -> {:error, "Missing required YouTube live parameters #{Enum.join(keys, ", ")}", keys}
    end
  end

  defp missing_param?(params, key) do
    value = get(params, key, nil)
    is_nil(value) or value == ""
  end

  defp params_list(params, key) do
    case get(params, key, []) do
      value when is_list(value) -> value
      value when is_binary(value) -> [value]
      _ -> []
    end
  end

  defp contains_any?(_text, []), do: false
  defp contains_any?(text, terms), do: Enum.any?(terms, &String.contains?(text, String.downcase(to_string(&1))))

  defp maybe_flag(flags, flag, true), do: [flag | flags]
  defp maybe_flag(flags, _flag, false), do: flags

  defp moderation_action(flags) do
    cond do
      :empty in flags -> :hold
      :blocked_term in flags -> :remove
      :link in flags -> :hold
      :highlight in flags -> :highlight
      true -> :allow
    end
  end

  defp maybe_issue(issues, issue, true), do: [issue | issues]
  defp maybe_issue(issues, _issue, false), do: issues

  defp prune_empty_values(value) when is_map(value) do
    value
    |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
    |> Map.new(fn {key, value} -> {key, prune_empty_values(value)} end)
  end

  defp prune_empty_values(value) when is_list(value), do: Enum.map(value, &prune_empty_values/1)
  defp prune_empty_values(value), do: value

  defp positive_integer(value, key) do
    case integer(value) do
      number when number > 0 -> {:ok, number}
      _ -> {:error, "Missing required YouTube live parameter #{key}", key}
    end
  end

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, rest} -> if String.trim(rest) == "", do: number, else: 0
      :error -> 0
    end
  end

  defp integer(_value), do: 0

  defp numeric(value) when is_integer(value), do: value
  defp numeric(value) when is_float(value), do: value

  defp numeric(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  defp numeric(_value), do: 0

  defp get(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end
end
