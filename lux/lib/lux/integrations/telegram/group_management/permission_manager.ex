defmodule Lux.Integrations.Telegram.GroupManagement.PermissionManager do
  @moduledoc """
  Manages Telegram chat permissions and permission presets for members and groups.
  """

  alias Lux.Integrations.Telegram.Client

  @valid_permissions [
    :can_send_messages,
    :can_send_audios,
    :can_send_documents,
    :can_send_photos,
    :can_send_videos,
    :can_send_video_notes,
    :can_send_voice_notes,
    :can_send_polls,
    :can_send_other_messages,
    :can_add_web_page_previews,
    :can_change_info,
    :can_invite_users,
    :can_pin_messages,
    :can_manage_topics
  ]

  @presets %{
    read_only: %{
      can_send_messages: false,
      can_send_audios: false,
      can_send_documents: false,
      can_send_photos: false,
      can_send_videos: false,
      can_send_video_notes: false,
      can_send_voice_notes: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_change_info: false,
      can_invite_users: false,
      can_pin_messages: false,
      can_manage_topics: false
    },
    text_only: %{
      can_send_messages: true,
      can_send_audios: false,
      can_send_documents: false,
      can_send_photos: false,
      can_send_videos: false,
      can_send_video_notes: false,
      can_send_voice_notes: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_change_info: false,
      can_invite_users: true,
      can_pin_messages: false,
      can_manage_topics: false
    },
    media_restricted: %{
      can_send_messages: true,
      can_send_audios: false,
      can_send_documents: false,
      can_send_photos: false,
      can_send_videos: false,
      can_send_video_notes: false,
      can_send_voice_notes: false,
      can_send_polls: true,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_change_info: false,
      can_invite_users: true,
      can_pin_messages: false,
      can_manage_topics: false
    },
    standard: %{
      can_send_messages: true,
      can_send_audios: true,
      can_send_documents: true,
      can_send_photos: true,
      can_send_videos: true,
      can_send_video_notes: true,
      can_send_voice_notes: true,
      can_send_polls: true,
      can_send_other_messages: true,
      can_add_web_page_previews: true,
      can_change_info: false,
      can_invite_users: true,
      can_pin_messages: false,
      can_manage_topics: false
    },
    moderator: %{
      can_send_messages: true,
      can_send_audios: true,
      can_send_documents: true,
      can_send_photos: true,
      can_send_videos: true,
      can_send_video_notes: true,
      can_send_voice_notes: true,
      can_send_polls: true,
      can_send_other_messages: true,
      can_add_web_page_previews: true,
      can_change_info: true,
      can_invite_users: true,
      can_pin_messages: true,
      can_manage_topics: true
    }
  }

  @doc """
  Returns a preset permission map.
  Available presets: `:read_only`, `:text_only`, `:media_restricted`, `:standard`, `:moderator`.
  """
  @spec get_preset(atom()) :: {:ok, map()} | {:error, term()}
  def get_preset(preset_name) when is_atom(preset_name) do
    case Map.get(@presets, preset_name) do
      nil -> {:error, {:unknown_preset, preset_name}}
      preset -> {:ok, preset}
    end
  end

  @doc """
  Sets default chat permissions for all members in a supergroup.
  """
  @spec set_chat_permissions(integer() | String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def set_chat_permissions(chat_id, permissions, opts \\ []) do
    payload =
      %{
        chat_id: chat_id,
        permissions: permissions
      }
      |> maybe_put(:use_independent_chat_permissions, opts[:use_independent_chat_permissions])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/setChatPermissions", request_opts)
  end

  @doc """
  Validates a permissions map against valid Telegram permission keys.
  """
  @spec validate_permissions(map()) :: {:ok, map()} | {:error, list(atom())}
  def validate_permissions(perms) when is_map(perms) do
    invalid =
      perms
      |> Map.keys()
      |> Enum.reject(&(&1 in @valid_permissions))

    if invalid == [] do
      {:ok, perms}
    else
      {:error, invalid}
    end
  end

  @doc """
  Checks if a ChatMember object has a specific permission.
  """
  def has_permission?(%{status: "creator"}, _perm), do: true
  def has_permission?(%{status: "administrator", can_manage_chat: true}, _perm), do: true

  def has_permission?(chat_member, perm) when is_map(chat_member) and is_atom(perm) do
    Map.get(chat_member, perm, false) == true
  end

  def has_permission?(_, _), do: false

  # --- Internal Helpers ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_put_plug(map, nil), do: map
  defp maybe_put_plug(map, plug), do: Map.put(map, :plug, plug)
end
