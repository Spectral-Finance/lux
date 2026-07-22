defmodule Lux.Integrations.YouTube.LiveMonitor do
  @moduledoc """
  A GenServer that polls stream health status and automates lifecycle state transitions
  for a YouTube Live Broadcast (ready -> testing -> live -> complete).
  """

  use GenServer
  require Logger

  alias Lux.Integrations.YouTube.Client

  # --- Client API ---

  @doc """
  Starts the LiveMonitor process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Transitions the broadcast state manually.
  """
  def transition(pid, status) do
    GenServer.call(pid, {:transition, status})
  end

  @doc """
  Gets the current status of the monitor (monitor state, broadcast status, and stream status).
  """
  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  @doc """
  Helper function to transition a broadcast state using the YouTube API.
  """
  def transition_broadcast(broadcast_id, status, access_token, plug, dry_run \\ false) do
    if dry_run do
      Logger.debug("[Dry-Run] Transitioning broadcast #{broadcast_id} to #{status}")
      {:ok, %{"id" => broadcast_id, "status" => %{"lifeCycleStatus" => status}}}
    else
      Client.request(:post, "/liveBroadcasts/transition", %{
        params: %{
          id: broadcast_id,
          broadcastStatus: status,
          part: "id,status"
        },
        access_token: access_token,
        plug: plug
      })
    end
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    state = %{
      broadcast_id: Keyword.fetch!(opts, :broadcast_id),
      stream_id: Keyword.fetch!(opts, :stream_id),
      access_token: Keyword.get(opts, :access_token),
      plug: Keyword.get(opts, :plug),
      poll_interval: Keyword.get(opts, :poll_interval, 5000),
      on_transition: Keyword.get(opts, :on_transition),
      dry_run: Keyword.get(opts, :dry_run, false) || Application.get_env(:lux, :youtube_dry_run, false) || System.get_env("YOUTUBE_DRY_RUN") == "true",
      status: "ready",
      stream_status: "inactive",
      stream_health: "noData"
    }

    # Start polling loop
    send(self(), :poll)

    {:ok, state}
  end

  @impl true
  def handle_call({:transition, status}, _from, state) do
    case transition_broadcast(state.broadcast_id, status, state.access_token, state.plug, state.dry_run) do
      {:ok, _response} ->
        Logger.info("Successfully transitioned broadcast #{state.broadcast_id} to #{status} manually")
        new_state = %{state | status: status}
        if state.on_transition, do: state.on_transition.(status)
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed manual transition of broadcast #{state.broadcast_id} to #{status}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, %{status: state.status, stream_status: state.stream_status, stream_health: state.stream_health}}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    # 1. Fetch current status
    {:ok, broadcast_status} = fetch_broadcast_status(state)
    {:ok, stream_status, stream_health} = fetch_stream_status(state)

    # 2. Automated state transition logic
    new_status =
      cond do
        broadcast_status == "ready" and (stream_status == "active" or stream_health == "good") ->
          Logger.info("Stream detected active/good. Transitioning broadcast #{state.broadcast_id} to testing.")
          case transition_broadcast(state.broadcast_id, "testing", state.access_token, state.plug, state.dry_run) do
            {:ok, _} -> "testing"
            _ -> "ready"
          end

        broadcast_status == "testing" ->
          # In testing state, check if we can go live.
          # Note: Google requires the broadcast to finish entering testing phase before going live.
          Logger.info("Broadcast #{state.broadcast_id} in testing phase. Transitioning to live.")
          case transition_broadcast(state.broadcast_id, "live", state.access_token, state.plug, state.dry_run) do
            {:ok, _} -> "live"
            _ -> "testing"
          end

        broadcast_status == "live" and (stream_status == "inactive" or stream_health == "noData") ->
          # Stream has stopped, transition to complete
          Logger.info("Stream inactive. Auto-transitioning broadcast #{state.broadcast_id} to complete.")
          case transition_broadcast(state.broadcast_id, "complete", state.access_token, state.plug, state.dry_run) do
            {:ok, _} -> "complete"
            _ -> "live"
          end

        true ->
          broadcast_status
      end

    if new_status != state.status do
      if state.on_transition, do: state.on_transition.(new_status)
    end

    new_state = %{state |
      status: new_status,
      stream_status: stream_status,
      stream_health: stream_health
    }

    # Schedule next poll unless complete
    if new_status != "complete" do
      Process.send_after(self(), :poll, state.poll_interval)
    end

    {:noreply, new_state}
  end

  # --- Helper functions ---

  defp fetch_broadcast_status(state) do
    if state.dry_run do
      {:ok, state.status}
    else
      case Client.request(:get, "/liveBroadcasts", %{
        params: %{
          id: state.broadcast_id,
          part: "status"
        },
        access_token: state.access_token,
        plug: state.plug
      }) do
        {:ok, %{"items" => [%{"status" => %{"lifeCycleStatus" => status}} | _]}} ->
          {:ok, status}
        _ ->
          {:ok, state.status}
      end
    end
  end

  defp fetch_stream_status(state) do
    if state.dry_run do
      # Simulate active stream during ready/testing/live and inactive when ending
      if state.status == "complete" do
        {:ok, "inactive", "noData"}
      else
        {:ok, "active", "good"}
      end
    else
      case Client.request(:get, "/liveStreams", %{
        params: %{
          id: state.stream_id,
          part: "status"
        },
        access_token: state.access_token,
        plug: state.plug
      }) do
        {:ok, %{"items" => [%{"status" => %{"streamStatus" => status} = s} | _]}} ->
          health = get_in(s, ["healthStatus", "status"]) || "good"
          {:ok, status, health}
        _ ->
          {:ok, state.stream_status, state.stream_health}
      end
    end
  end
end
