defmodule Lux.Integrations.Telegram.GroupManagement.MemberManager do
  @moduledoc """
  Telegram group and channel member administration.
  Provides functions to ban, unban, restrict, promote members, assign custom titles,
  and inspect chat administrators and member counts.
  """

  alias Lux.Integrations.Telegram.Client
  require Logger

  @doc """
  Bans a user from a chat or channel.

  ## Options:
    - `:until_date` - Date when the user will be unbanned (Unix timestamp). If 0 or omitted, banned permanently.
    - `:revoke_messages` - Pass true to delete all messages from the chat for the user that is being removed.
    - `:plug` - Optional test plug.
  """
  @spec ban_member(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def ban_member(chat_id, user_id, opts \\ []) do
    payload =
      %{chat_id: chat_id, user_id: user_id}
      |> maybe_put(:until_date, opts[:until_date])
      |> maybe_put(:revoke_messages, opts[:revoke_messages])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/banChatMember", request_opts)
  end

  @doc """
  Unbans a previously banned user in a supergroup or channel.

  ## Options:
    - `:only_if_banned` - Do nothing if the user has not been banned.
    - `:plug` - Optional test plug.
  """
  @spec unban_member(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def unban_member(chat_id, user_id, opts \\ []) do
    payload =
      %{chat_id: chat_id, user_id: user_id}
      |> maybe_put(:only_if_banned, opts[:only_if_banned])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/unbanChatMember", request_opts)
  end

  @doc """
  Restricts a user in a supergroup.

  ## Options:
    - `:until_date` - Date when restrictions will be lifted (Unix timestamp).
    - `:use_independent_chat_permissions` - Pass true if chat permissions are set independently.
    - `:plug` - Optional test plug.
  """
  @spec restrict_member(integer() | String.t(), integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def restrict_member(chat_id, user_id, permissions, opts \\ []) do
    payload =
      %{
        chat_id: chat_id,
        user_id: user_id,
        permissions: permissions
      }
      |> maybe_put(:until_date, opts[:until_date])
      |> maybe_put(:use_independent_chat_permissions, opts[:use_independent_chat_permissions])

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/restrictChatMember", request_opts)
  end

  @doc """
  Promotes or demotes a user in a supergroup or an official channel.
  """
  @spec promote_member(integer() | String.t(), integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def promote_member(chat_id, user_id, privileges, opts \\ []) do
    payload =
      Map.merge(
        %{chat_id: chat_id, user_id: user_id},
        privileges
      )

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/promoteChatMember", request_opts)
  end

  @doc """
  Sets a custom title for an administrator in a supergroup promoted by the bot.
  """
  @spec set_admin_title(integer() | String.t(), integer(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def set_admin_title(chat_id, user_id, custom_title, opts \\ []) do
    payload = %{
      chat_id: chat_id,
      user_id: user_id,
      custom_title: custom_title
    }

    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/setChatAdministratorCustomTitle", request_opts)
  end

  @doc """
  Gets detailed information about a member of a chat.
  """
  @spec get_chat_member(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_chat_member(chat_id, user_id, opts \\ []) do
    payload = %{chat_id: chat_id, user_id: user_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/getChatMember", request_opts)
  end

  @doc """
  Gets the number of members in a chat.
  """
  @spec get_chat_member_count(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_chat_member_count(chat_id, opts \\ []) do
    payload = %{chat_id: chat_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/getChatMemberCount", request_opts)
  end

  @doc """
  Gets a list of administrators in a chat.
  """
  @spec get_chat_administrators(integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_chat_administrators(chat_id, opts \\ []) do
    payload = %{chat_id: chat_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/getChatAdministrators", request_opts)
  end

  # --- Internal Helpers ---

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_put_plug(map, nil), do: map
  defp maybe_put_plug(map, plug), do: Map.put(map, :plug, plug)
end
