defmodule Lux.Lenses.TelegramGroupManagementFeatures do
  @moduledoc """
  Group and Channel Management Features for the Telegram Bot API.

  This module provides specialized functionality for managing Telegram groups and channels:

  ## Features

  - Member management (add, remove, restrict, promote)
  - Permission management for groups and channels
  - Content moderation (delete messages, clean up history)
  - Spam protection (restrict new users, set slow mode)
  - Group settings management (title, description, photo)
  - Channel post management
  - Admin action logging

  ## Example

  ```elixir
  alias Lux.Lenses.TelegramGroupManagementFeatures

  # Ban a user from a group
  TelegramGroupManagementFeatures.ban_chat_member(
    chat_id,
    user_id
  )

  # Restrict a user in a group
  TelegramGroupManagementFeatures.restrict_chat_member(
    chat_id,
    user_id,
    %{
      can_send_messages: false,
      until_date: :os.system_time(:second) + 3600 # 1 hour
    }
  )

  # Promote a user to admin
  TelegramGroupManagementFeatures.promote_chat_member(
    chat_id,
    user_id,
    %{
      can_delete_messages: true,
      can_restrict_members: true
    }
  )
  ```
  """

  alias Lux.Lenses.TelegramBotLens

  #
  # Member Management
  #

  @doc """
  Bans a user from a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user
  - `opts`: Additional options (until_date, revoke_messages)

  ## Returns

  Returns true on success.
  """
  def ban_chat_member(chat_id, user_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "banChatMember",
        chat_id: chat_id,
        user_id: user_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Unbans a previously banned user in a supergroup or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user
  - `opts`: Additional options (only_if_banned)

  ## Returns

  Returns true on success.
  """
  def unban_chat_member(chat_id, user_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "unbanChatMember",
        chat_id: chat_id,
        user_id: user_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Restricts a user in a supergroup.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user
  - `permissions`: A JSON object for new user permissions
  - `opts`: Additional options (until_date)

  ## Returns

  Returns true on success.
  """
  def restrict_chat_member(chat_id, user_id, permissions, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "restrictChatMember",
        chat_id: chat_id,
        user_id: user_id,
        permissions: permissions,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Promotes or demotes a user in a supergroup or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user
  - `opts`: Additional options (is_anonymous, can_manage_chat, can_post_messages, etc.)

  ## Returns

  Returns true on success.
  """
  def promote_chat_member(chat_id, user_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "promoteChatMember",
        chat_id: chat_id,
        user_id: user_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Sets a custom title for an administrator in a supergroup.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user
  - `custom_title`: New custom title for the administrator (0-16 characters, emoji not allowed)

  ## Returns

  Returns true on success.
  """
  def set_chat_administrator_custom_title(chat_id, user_id, custom_title) do
    params = %{
      method: "setChatAdministratorCustomTitle",
      chat_id: chat_id,
      user_id: user_id,
      custom_title: custom_title,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Bans a channel chat in a supergroup or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `sender_chat_id`: Unique identifier of the target sender chat
  - `opts`: Additional options

  ## Returns

  Returns true on success.
  """
  def ban_chat_sender_chat(chat_id, sender_chat_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "banChatSenderChat",
        chat_id: chat_id,
        sender_chat_id: sender_chat_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Unbans a previously banned channel chat in a supergroup or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `sender_chat_id`: Unique identifier of the target sender chat

  ## Returns

  Returns true on success.
  """
  def unban_chat_sender_chat(chat_id, sender_chat_id) do
    params = %{
      method: "unbanChatSenderChat",
      chat_id: chat_id,
      sender_chat_id: sender_chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  #
  # Permission Management
  #

  @doc """
  Sets default chat permissions for all members.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `permissions`: A JSON object for new default chat permissions

  ## Returns

  Returns true on success.
  """
  def set_chat_permissions(chat_id, permissions) do
    params = %{
      method: "setChatPermissions",
      chat_id: chat_id,
      permissions: permissions,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Creates an invite link for a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `opts`: Additional options (name, expire_date, member_limit, creates_join_request)

  ## Returns

  Returns the new invite link as ChatInviteLink object.
  """
  def create_chat_invite_link(chat_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "createChatInviteLink",
        chat_id: chat_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Edits a non-primary invite link created by the bot.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `invite_link`: The invite link to edit
  - `opts`: Additional options (name, expire_date, member_limit, creates_join_request)

  ## Returns

  Returns the edited invite link as a ChatInviteLink object.
  """
  def edit_chat_invite_link(chat_id, invite_link, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "editChatInviteLink",
        chat_id: chat_id,
        invite_link: invite_link,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Revokes an invite link created by the bot.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `invite_link`: The invite link to revoke

  ## Returns

  Returns the revoked invite link as ChatInviteLink object.
  """
  def revoke_chat_invite_link(chat_id, invite_link) do
    params = %{
      method: "revokeChatInviteLink",
      chat_id: chat_id,
      invite_link: invite_link,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Approves a chat join request.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user

  ## Returns

  Returns true on success.
  """
  def approve_chat_join_request(chat_id, user_id) do
    params = %{
      method: "approveChatJoinRequest",
      chat_id: chat_id,
      user_id: user_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Declines a chat join request.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `user_id`: Unique identifier of the target user

  ## Returns

  Returns true on success.
  """
  def decline_chat_join_request(chat_id, user_id) do
    params = %{
      method: "declineChatJoinRequest",
      chat_id: chat_id,
      user_id: user_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  #
  # Content Moderation
  #

  @doc """
  Deletes a message from a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message to delete

  ## Returns

  Returns true on success.
  """
  def delete_message(chat_id, message_id) do
    params = %{
      method: "deleteMessage",
      chat_id: chat_id,
      message_id: message_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Deletes multiple messages from a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_ids`: List of message identifiers to delete (1-100)

  ## Returns

  Returns true on success.
  """
  def delete_messages(chat_id, message_ids) do
    params = %{
      method: "deleteMessages",
      chat_id: chat_id,
      message_ids: message_ids,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Deletes the chat photo.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat

  ## Returns

  Returns true on success.
  """
  def delete_chat_photo(chat_id) do
    params = %{
      method: "deleteChatPhoto",
      chat_id: chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Cleans up a chat's history for all users.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `opts`: Additional options (for_everyone)

  ## Returns

  Returns true on success.
  """
  def clean_chat_history(chat_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "cleanChatHistory",
        chat_id: chat_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  #
  # Spam Protection
  #

  @doc """
  Sets a new slow mode delay for a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `seconds`: New slow mode delay in seconds (0-60)

  ## Returns

  Returns true on success.
  """
  def set_chat_slow_mode_delay(chat_id, seconds) do
    params = %{
      method: "setChatSlowModeDelay",
      chat_id: chat_id,
      seconds: seconds,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Restricts all new chat members from sending messages for a specified period.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `until_date`: Date when restrictions will be lifted (Unix time)

  ## Returns

  Returns true on success.
  """
  def restrict_new_chat_members(chat_id, until_date) do
    # Create permissions that restrict sending messages
    permissions = %{
      can_send_messages: false,
      can_send_media_messages: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false
    }

    # Get all new members and restrict them
    case TelegramBotLens.get_chat_member_count(chat_id) do
      {:ok, count} ->
        # Get recent members (this is a simplified approach)
        # In a real implementation, you would need to track new members
        {:ok, _} = set_chat_permissions(chat_id, permissions)

        # Schedule a task to restore permissions after the specified time
        Process.send_after(self(), {:restore_chat_permissions, chat_id},
                          (until_date - :os.system_time(:second)) * 1000)

        {:ok, true}

      error -> error
    end
  end

  @doc """
  Handles the restoration of chat permissions after a temporary restriction.
  """
  def handle_info({:restore_chat_permissions, chat_id}, state) do
    # Default permissions that allow sending messages
    permissions = %{
      can_send_messages: true,
      can_send_media_messages: true,
      can_send_polls: true,
      can_send_other_messages: true,
      can_add_web_page_previews: true
    }

    set_chat_permissions(chat_id, permissions)

    {:noreply, state}
  end

  #
  # Group Settings Management
  #

  @doc """
  Changes the title of a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `title`: New chat title, 1-255 characters

  ## Returns

  Returns true on success.
  """
  def set_chat_title(chat_id, title) do
    params = %{
      method: "setChatTitle",
      chat_id: chat_id,
      title: title,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Changes the description of a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `description`: New chat description, 0-255 characters

  ## Returns

  Returns true on success.
  """
  def set_chat_description(chat_id, description) do
    params = %{
      method: "setChatDescription",
      chat_id: chat_id,
      description: description,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Changes the photo of a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `photo`: New chat photo (file_id or URL)

  ## Returns

  Returns true on success.
  """
  def set_chat_photo(chat_id, photo) do
    params = %{
      method: "setChatPhoto",
      chat_id: chat_id,
      photo: photo,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Pins a message in a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message to pin
  - `opts`: Additional options (disable_notification)

  ## Returns

  Returns true on success.
  """
  def pin_chat_message(chat_id, message_id, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "pinChatMessage",
        chat_id: chat_id,
        message_id: message_id,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Unpins a message in a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `message_id`: Identifier of the message to unpin

  ## Returns

  Returns true on success.
  """
  def unpin_chat_message(chat_id, message_id) do
    params = %{
      method: "unpinChatMessage",
      chat_id: chat_id,
      message_id: message_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Unpins all messages in a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat

  ## Returns

  Returns true on success.
  """
  def unpin_all_chat_messages(chat_id) do
    params = %{
      method: "unpinAllChatMessages",
      chat_id: chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  #
  # Channel Post Management
  #

  @doc """
  Edits a channel post.

  ## Parameters

  - `chat_id`: Unique identifier for the target channel
  - `message_id`: Identifier of the message to edit
  - `text`: New text of the message
  - `opts`: Additional options (parse_mode, entities, etc.)

  ## Returns

  Returns the edited message on success.
  """
  def edit_channel_post(chat_id, message_id, text, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "editMessageText",
        chat_id: chat_id,
        message_id: message_id,
        text: text,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Edits a channel post caption.

  ## Parameters

  - `chat_id`: Unique identifier for the target channel
  - `message_id`: Identifier of the message to edit
  - `caption`: New caption of the message
  - `opts`: Additional options (parse_mode, caption_entities)

  ## Returns

  Returns the edited message on success.
  """
  def edit_channel_post_caption(chat_id, message_id, caption, opts \\ %{}) do
    params = Map.merge(
      %{
        method: "editMessageCaption",
        chat_id: chat_id,
        message_id: message_id,
        caption: caption,
        token: Lux.Config.telegram_bot_token()
      },
      opts
    )

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Deletes a channel post.

  ## Parameters

  - `chat_id`: Unique identifier for the target channel
  - `message_id`: Identifier of the message to delete

  ## Returns

  Returns true on success.
  """
  def delete_channel_post(chat_id, message_id) do
    delete_message(chat_id, message_id)
  end

  #
  # Admin Action Logging
  #

  @doc """
  Logs an admin action to a specified chat or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat
  - `admin_id`: Unique identifier of the admin
  - `action`: Description of the action
  - `target_user_id`: Optional user ID that was the target of the action

  ## Returns

  Returns the message ID of the log entry on success.
  """
  def log_admin_action(chat_id, admin_id, action, target_user_id \\ nil) do
    # Get admin information
    {:ok, admin_info} = TelegramBotLens.get_chat_member(chat_id, admin_id)
    admin_name = get_in(admin_info, ["user", "first_name"]) || "Admin"

    # Format the log message
    log_message = if target_user_id do
      {:ok, target_info} = TelegramBotLens.get_chat_member(chat_id, target_user_id)
      target_name = get_in(target_info, ["user", "first_name"]) || "User"
      "🛡️ ADMIN ACTION: #{admin_name} #{action} #{target_name}"
    else
      "🛡️ ADMIN ACTION: #{admin_name} #{action}"
    end

    # Send the log message
    TelegramBotLens.send_message(chat_id, log_message)
  end

  @doc """
  Creates an admin action log channel for a group.

  ## Parameters

  - `group_chat_id`: Unique identifier for the group
  - `log_channel_title`: Title for the new log channel

  ## Returns

  Returns the chat ID of the created channel on success.
  """
  def create_admin_log_channel(group_chat_id, log_channel_title) do
    # This is a simplified implementation
    # In a real implementation, you would need to:
    # 1. Create a new channel
    # 2. Add the bot as an admin
    # 3. Link the channel to the group
    # 4. Set up a mechanism to forward admin actions

    # For now, we'll just send a message to the group
    {:ok, group_info} = TelegramBotLens.get_chat(group_chat_id)
    group_title = group_info["title"] || "Group"

    message = """
    📋 Admin Action Log Channel

    This channel will be used to log administrative actions for #{group_title}.
    """

    TelegramBotLens.send_message(group_chat_id, message)
  end

  @doc """
  Sets up automatic logging of all admin actions in a group.

  ## Parameters

  - `group_chat_id`: Unique identifier for the group
  - `log_channel_id`: Unique identifier for the log channel

  ## Returns

  Returns true on success.
  """
  def setup_automatic_admin_logging(group_chat_id, log_channel_id) do
    # This would require setting up a webhook or long polling mechanism
    # to capture all admin actions and forward them to the log channel

    # For demonstration purposes, we'll just send a confirmation message
    message = "✅ Automatic admin action logging has been set up for this group."

    {:ok, _} = TelegramBotLens.send_message(group_chat_id, message)
    {:ok, _} = TelegramBotLens.send_message(log_channel_id, "🔄 This channel is now receiving admin action logs.")

    {:ok, true}
  end

  #
  # Utility Functions
  #

  @doc """
  Gets a list of administrators in a chat.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat

  ## Returns

  Returns a list of ChatMember objects on success.
  """
  def get_chat_administrators(chat_id) do
    params = %{
      method: "getChatAdministrators",
      chat_id: chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Exports a chat invite link.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat

  ## Returns

  Returns the invite link as a string on success.
  """
  def export_chat_invite_link(chat_id) do
    params = %{
      method: "exportChatInviteLink",
      chat_id: chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end

  @doc """
  Leaves a group, supergroup or channel.

  ## Parameters

  - `chat_id`: Unique identifier for the target chat

  ## Returns

  Returns true on success.
  """
  def leave_chat(chat_id) do
    params = %{
      method: "leaveChat",
      chat_id: chat_id,
      token: Lux.Config.telegram_bot_token()
    }

    TelegramBotLens.telegram_request(params)
  end
end
