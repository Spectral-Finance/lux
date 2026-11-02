defmodule Lux.Integrations.Telegram.GroupManagement.SettingsManager do
  @moduledoc """
  Manages Telegram group and channel settings, slow mode, invite links,
  and membership join requests.
  """

  alias Lux.Integrations.Telegram.Client

  @doc """
  Changes the title of a chat (supergroup or channel).
  """
  @spec set_chat_title(integer() | String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def set_chat_title(chat_id, title, opts \\ []) do
    payload = %{chat_id: chat_id, title: title}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/setChatTitle", request_opts)
  end

  @doc """
  Changes the description of a group, supergroup, or channel.
  """
  @spec set_chat_description(integer() | String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def set_chat_description(chat_id, description, opts \\ []) do
    payload = %{chat_id: chat_id, description: description}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/setChatDescription", request_opts)
  end

  @doc """
  Sets slow mode delay for a supergroup in seconds (0 to 21600).
  """
  @spec set_slow_mode(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def set_slow_mode(chat_id, slow_mode_delay, opts \\ []) do
    payload = %{chat_id: chat_id, slow_mode_delay: slow_mode_delay}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/setChatSlowModeDelay", request_opts)
  end

  @doc """
  Generates a new primary invite link for a chat; any previously generated primary link is revoked.
  """
  @spec export_invite_link(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def export_invite_link(chat_id, opts \\ []) do
    payload = %{chat_id: chat_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/exportChatInviteLink", request_opts)
  end

  @doc """
  Creates an additional invite link for a chat.

  ## Options:
    - `:name` - Invite link name (0-32 characters).
    - `:expire_date` - Point in time (Unix timestamp) when the link will expire.
    - `:member_limit` - The maximum number of users that can be members simultaneously.
    - `:creates_join_request` - Pass true if users joining the link need to be approved by chat administrators.
  """
  @spec create_invite_link(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_invite_link(chat_id, opts \\ []) do
    payload =
      %{chat_id: chat_id}
      |> maybe_put(:name, opts[:name])
      |> maybe_put(:expire_date, opts[:expire_date])
      |> maybe_put(:member_limit, opts[:member_limit])
      |> maybe_put(:creates_join_request, opts[:creates_join_request])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/createChatInviteLink", request_opts)
  end

  @doc """
  Edits a non-primary invite link created by the bot.
  """
  @spec edit_invite_link(integer() | String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def edit_invite_link(chat_id, invite_link, opts \\ []) do
    payload =
      %{chat_id: chat_id, invite_link: invite_link}
      |> maybe_put(:name, opts[:name])
      |> maybe_put(:expire_date, opts[:expire_date])
      |> maybe_put(:member_limit, opts[:member_limit])
      |> maybe_put(:creates_join_request, opts[:creates_join_request])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/editChatInviteLink", request_opts)
  end

  @doc """
  Revokes an invite link created by the bot.
  """
  @spec revoke_invite_link(integer() | String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def revoke_invite_link(chat_id, invite_link, opts \\ []) do
    payload = %{chat_id: chat_id, invite_link: invite_link}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/revokeChatInviteLink", request_opts)
  end

  @doc """
  Approves a chat join request.
  """
  @spec approve_join_request(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def approve_join_request(chat_id, user_id, opts \\ []) do
    payload = %{chat_id: chat_id, user_id: user_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/approveChatJoinRequest", request_opts)
  end

  @doc """
  Declines a chat join request.
  """
  @spec decline_join_request(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def decline_join_request(chat_id, user_id, opts \\ []) do
    payload = %{chat_id: chat_id, user_id: user_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/declineChatJoinRequest", request_opts)
  end

  # --- Internal Helpers ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_put_plug(map, nil), do: map
  defp maybe_put_plug(map, plug), do: Map.put(map, :plug, plug)
end
