defmodule Lux.Prisms.YouTube.PlaylistOrganizer do
  @moduledoc """
  Organize and manage playlists with auto-categorization and ordering.
  """

  use GenServer

  defstruct [:playlists]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def create_playlist(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:create, params})
  end

  def add_video(pid \\ __MODULE__, playlist_id, video) do
    GenServer.call(pid, {:add_video, playlist_id, video})
  end

  def remove_video(pid \\ __MODULE__, playlist_id, video_id) do
    GenServer.call(pid, {:remove_video, playlist_id, video_id})
  end

  def reorder(pid \\ __MODULE__, playlist_id, video_id, new_position) do
    GenServer.call(pid, {:reorder, playlist_id, video_id, new_position})
  end

  def get_playlist(pid \\ __MODULE__, playlist_id) do
    GenServer.call(pid, {:get, playlist_id})
  end

  def list_playlists(pid \\ __MODULE__) do
    GenServer.call(pid, :list)
  end

  def auto_categorize(pid \\ __MODULE__, videos) do
    GenServer.call(pid, {:auto_categorize, videos})
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{playlists: %{}}}

  @impl true
  def handle_call({:create, params}, _from, state) do
    id = params[:id] || gen_id()
    playlist = %{
      id: id,
      title: params[:title],
      description: params[:description] || "",
      videos: [],
      tags: params[:tags] || [],
      visibility: params[:visibility] || :public,
      created_at: DateTime.utc_now()
    }
    {:reply, {:ok, playlist}, %{state | playlists: Map.put(state.playlists, id, playlist)}}
  end

  @impl true
  def handle_call({:add_video, playlist_id, video}, _from, state) do
    case Map.get(state.playlists, playlist_id) do
      nil -> {:reply, {:error, :not_found}, state}
      playlist ->
        entry = %{video_id: video[:id], title: video[:title], added_at: DateTime.utc_now()}
        updated = %{playlist | videos: playlist.videos ++ [entry]}
        {:reply, {:ok, updated}, %{state | playlists: Map.put(state.playlists, playlist_id, updated)}}
    end
  end

  @impl true
  def handle_call({:remove_video, playlist_id, video_id}, _from, state) do
    case Map.get(state.playlists, playlist_id) do
      nil -> {:reply, {:error, :not_found}, state}
      playlist ->
        updated = %{playlist | videos: Enum.reject(playlist.videos, &(&1.video_id == video_id))}
        {:reply, {:ok, updated}, %{state | playlists: Map.put(state.playlists, playlist_id, updated)}}
    end
  end

  @impl true
  def handle_call({:reorder, playlist_id, video_id, new_pos}, _from, state) do
    case Map.get(state.playlists, playlist_id) do
      nil -> {:reply, {:error, :not_found}, state}
      playlist ->
        {video, rest} = case Enum.split_with(playlist.videos, &(&1.video_id == video_id)) do
          {[v], r} -> {v, r}
          _ -> {nil, playlist.videos}
        end
        if video do
          videos = List.insert_at(rest, min(new_pos, length(rest)), video)
          updated = %{playlist | videos: videos}
          {:reply, {:ok, updated}, %{state | playlists: Map.put(state.playlists, playlist_id, updated)}}
        else
          {:reply, {:error, :video_not_found}, state}
        end
    end
  end

  @impl true
  def handle_call({:get, playlist_id}, _from, state) do
    case Map.get(state.playlists, playlist_id) do
      nil -> {:reply, {:error, :not_found}, state}
      p -> {:reply, {:ok, p}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, {:ok, Map.values(state.playlists)}, state}
  end

  @impl true
  def handle_call({:auto_categorize, videos}, _from, state) do
    categories = Enum.group_by(videos, fn video ->
      tags = (video[:tags] || []) |> Enum.map(&String.downcase/1)
      cond do
        Enum.any?(tags, &(&1 in ~w(tutorial how-to guide learn))) -> :tutorials
        Enum.any?(tags, &(&1 in ~w(review comparison unboxing))) -> :reviews
        Enum.any?(tags, &(&1 in ~w(vlog daily life))) -> :vlogs
        true -> :uncategorized
      end
    end)
    {:reply, {:ok, categories}, state}
  end

  defp gen_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
