defmodule Lux.Integrations.Discord.Presence do
  @moduledoc """
  Discord Rich Presence and status management.

  Builds properly-structured Gateway presence update payloads and provides
  activity type definitions per the
  [Discord Gateway documentation](https://discord.com/developers/docs/topics/gateway#update-presence).

  ## Activity Types

  Discord supports these activity types:
    * `0` - Playing
    * `1` - Streaming
    * `2` - Listening
    * `3` - Watching
    * `4` - Custom
    * `5` - Competing

  ## Usage

      payload = Presence.build_presence_update(
        status: :online,
        activities: [%{name: "with Elixir", type: :playing}]
      )
      # Send via Gateway: %{op: 3, d: payload}

  """

  @activity_types %{
    playing: 0,
    streaming: 1,
    listening: 2,
    watching: 3,
    custom: 4,
    competing: 5
  }

  @valid_statuses ~w(online dnd idle invisible offline)

  @type activity :: %{
          name: String.t(),
          type: non_neg_integer(),
          url: String.t() | nil,
          state: String.t() | nil,
          details: String.t() | nil,
          timestamps: map() | nil,
          assets: map() | nil,
          buttons: [String.t()] | nil,
          metadata: map() | nil
        }

  @doc """
  Builds a complete Gateway presence update payload (opcode 3).

  ## Options

    * `:status` - Status atom or string (`:online`, `:dnd`, `:idle`, `:invisible`, `:offline`)
    * `:activities` - List of activity maps
    * `:since` - Unix timestamp (ms) of when the bot went idle, or `nil`
    * `:afk` - Whether the bot is AFK (default: `false`)

  ## Examples

      iex> Presence.build_presence_update(
      ...>   status: :online,
      ...>   activities: [%{name: "Elixir", type: :playing}]
      ...> )
      %{
        since: nil,
        activities: [%{name: "Elixir", type: 0}],
        status: "online",
        afk: false
      }

  """
  @spec build_presence_update(keyword()) :: map()
  def build_presence_update(opts \\ []) do
    status = Keyword.get(opts, :status, :online) |> normalize_status()
    activities = Keyword.get(opts, :activities, []) |> Enum.map(&build_activity/1)
    since = Keyword.get(opts, :since)
    afk = Keyword.get(opts, :afk, false)

    %{
      since: since,
      activities: activities,
      status: status,
      afk: afk
    }
  end

  @doc """
  Builds a Gateway opcode 3 wrapper around a presence update.

  This is the full payload that should be sent to the Discord Gateway.

  ## Examples

      iex> Presence.gateway_presence_payload(status: :online, activities: [])
      %{op: 3, d: %{since: nil, activities: [], status: "online", afk: false}}

  """
  @spec gateway_presence_payload(keyword()) :: map()
  def gateway_presence_payload(opts \\ []) do
    %{op: 3, d: build_presence_update(opts)}
  end

  @doc """
  Builds a custom status activity (type 4).

  Custom statuses display as the user's status text with an optional emoji.

  ## Parameters

    * `text` - The status text (max 128 characters)
    * `opts` - Options including `:emoji_name`, `:emoji_id`, `:state`

  ## Examples

      iex> Presence.custom_status("Building things")
      %{name: "Custom Status", type: 4, state: "Building things"}

      iex> Presence.custom_status("Working", emoji_name: "rocket")
      %{name: "Custom Status", type: 4, state: "Working", emoji: %{name: "rocket"}}

  """
  @spec custom_status(String.t(), keyword()) :: map()
  def custom_status(text, opts \\ []) do
    emoji =
      case {Keyword.get(opts, :emoji_name), Keyword.get(opts, :emoji_id)} do
        {nil, nil} -> nil
        {name, id} -> %{name: name, id: id, animated: Keyword.get(opts, :emoji_animated, false)}
      end

    %{
      name: "Custom Status",
      type: @activity_types.custom,
      state: text
    }
    |> maybe_put(:emoji, emoji)
  end

  @doc """
  Builds a "Playing" activity (type 0).

  ## Examples

      iex> Presence.playing("Elixir")
      %{name: "Elixir", type: 0}

  """
  @spec playing(String.t()) :: map()
  def playing(name), do: %{name: name, type: @activity_types.playing}

  @doc """
  Builds a "Streaming" activity (type 1).

  Requires a Twitch or YouTube URL.

  ## Examples

      iex> Presence.streaming("My Stream", "https://twitch.tv/mychannel")
      %{name: "My Stream", type: 1, url: "https://twitch.tv/mychannel"}

  """
  @spec streaming(String.t(), String.t()) :: map()
  def streaming(name, url), do: %{name: name, type: @activity_types.streaming, url: url}

  @doc """
  Builds a "Listening" activity (type 2).

  ## Examples

      iex> Presence.listening("Spotify")
      %{name: "Spotify", type: 2}

  """
  @spec listening(String.t()) :: map()
  def listening(name), do: %{name: name, type: @activity_types.listening}

  @doc """
  Builds a "Watching" activity (type 3).

  ## Examples

      iex> Presence.watching("a movie")
      %{name: "a movie", type: 3}

  """
  @spec watching(String.t()) :: map()
  def watching(name), do: %{name: name, type: @activity_types.watching}

  @doc """
  Builds a "Competing" activity (type 5).

  ## Examples

      iex> Presence.competing("in a tournament")
      %{name: "in a tournament", type: 5}

  """
  @spec competing(String.t()) :: map()
  def competing(name), do: %{name: name, type: @activity_types.competing}

  @doc """
  Builds a rich activity with full metadata.

  Supports timestamps for elapsed/remaining time, assets for large/small images,
  buttons for interactive links, and metadata for secrets.

  ## Parameters

    * `name` - Activity name
    * `type` - Activity type atom (`:playing`, `:streaming`, `:listening`, `:watching`, `:competing`)
    * `opts` - Rich options: `:url`, `:state`, `:details`, `:start`, `:end`, `:large_image`,
      `:large_text`, `:small_image`, `:small_text`, `:buttons`, `:metadata`

  ## Examples

      iex> Presence.rich_activity("Spotify", :listening,
      ...>   details: "Song Name",
      ...>   state: "Artist Name",
      ...>   large_image: "spotify:albumart",
      ...>   large_text: "Album Name",
      ...>   start: 1609459200000
      ...> )
      %{
        name: "Spotify",
        type: 2,
        details: "Song Name",
        state: "Artist Name",
        timestamps: %{start: 1609459200000},
        assets: %{large_image: "spotify:albumart", large_text: "Album Name"}
      }

  """
  @spec rich_activity(String.t(), atom(), keyword()) :: map()
  def rich_activity(name, type, opts \\ []) do
    activity_type = Map.get(@activity_types, type, 0)

    timestamps =
      case {Keyword.get(opts, :start), Keyword.get(opts, :end)} do
        {nil, nil} -> nil
        {s, e} -> %{start: s, end: e} |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()
      end

    assets =
      case {Keyword.get(opts, :large_image), Keyword.get(opts, :small_image)} do
        {nil, nil} ->
          nil

        _ ->
          %{
            large_image: Keyword.get(opts, :large_image),
            large_text: Keyword.get(opts, :large_text),
            small_image: Keyword.get(opts, :small_image),
            small_text: Keyword.get(opts, :small_text)
          }
          |> Enum.reject(fn {_, v} -> is_nil(v) end)
          |> Map.new()
      end

    %{
      name: name,
      type: activity_type
    }
    |> maybe_put(:url, Keyword.get(opts, :url))
    |> maybe_put(:state, Keyword.get(opts, :state))
    |> maybe_put(:details, Keyword.get(opts, :details))
    |> maybe_put(:timestamps, timestamps)
    |> maybe_put(:assets, assets)
    |> maybe_put(:buttons, Keyword.get(opts, :buttons))
    |> maybe_put(:metadata, Keyword.get(opts, :metadata))
  end

  @doc """
  Returns the map of activity type names to Discord integer codes.
  """
  @spec activity_types() :: map()
  def activity_types, do: @activity_types

  @doc """
  Returns the list of valid status strings.
  """
  @spec valid_statuses() :: [String.t()]
  def valid_statuses, do: @valid_statuses

  @doc """
  Validates a status string or atom.

  ## Examples

      iex> Presence.validate_status(:online)
      {:ok, "online"}

      iex> Presence.validate_status("dnd")
      {:ok, "dnd"}

      iex> Presence.validate_status("invalid")
      {:error, :invalid_status}

  """
  @spec validate_status(atom() | String.t()) :: {:ok, String.t()} | {:error, term()}
  def validate_status(status) when is_atom(status) do
    str = Atom.to_string(status)
    if str in @valid_statuses, do: {:ok, str}, else: {:error, :invalid_status}
  end

  def validate_status(status) when is_binary(status) do
    if status in @valid_statuses, do: {:ok, status}, else: {:error, :invalid_status}
  end

  def validate_status(_), do: {:error, :invalid_status}

  @doc """
  Validates an activity type atom or integer.

  ## Examples

      iex> Presence.validate_activity_type(:playing)
      {:ok, 0}

      iex> Presence.validate_activity_type(2)
      {:ok, 2}

      iex> Presence.validate_activity_type(:unknown)
      {:error, :invalid_activity_type}

  """
  @spec validate_activity_type(atom() | non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def validate_activity_type(type) when is_atom(type) do
    case Map.get(@activity_types, type) do
      nil -> {:error, :invalid_activity_type}
      val -> {:ok, val}
    end
  end

  def validate_activity_type(type) when is_integer(type) and type >= 0 and type <= 5 do
    {:ok, type}
  end

  def validate_activity_type(_), do: {:error, :invalid_activity_type}

  # Private helpers

  defp build_activity(%{type: type} = activity) when is_atom(type) do
    activity
    |> Map.update!(:type, &Map.get(@activity_types, &1, 0))
  end

  defp build_activity(%{type: type} = activity) when is_integer(type), do: activity
  defp build_activity(%{name: _} = activity), do: Map.put(activity, :type, 0)
  defp build_activity(activity) when is_map(activity), do: Map.put(activity, :type, 0)

  defp normalize_status(status) when is_atom(status), do: Atom.to_string(status)
  defp normalize_status(status) when is_binary(status), do: status

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
