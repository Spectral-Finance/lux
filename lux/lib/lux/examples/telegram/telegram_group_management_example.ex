defmodule Lux.Examples.TelegramGroupManagementExample do
  @moduledoc """
  Example demonstrating Telegram Group Management features.
  All examples perform real operations since the bot has admin permissions.

  ## Usage

  ```elixir
  # Run the complete example
  Lux.Examples.TelegramGroupManagementExample.run(chat_id)

  # Run a specific section
  Lux.Examples.TelegramGroupManagementExample.demonstrate_member_management(chat_id)
  ```
  """

  alias Lux.Lenses.TelegramBotLens
  alias Lux.Lenses.TelegramGroupManagementFeatures, as: GroupMgmt

  @doc """
  Runs the complete example, demonstrating all group management features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:user_id`: ID of a user to use for member management examples (required)
    - `:delay`: Delay between actions in milliseconds (default: 1000)
  """
  def run(chat_id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    delay = Keyword.get(opts, :delay, 1000)

    unless user_id do
      raise "user_id is required for running the examples"
    end

    # Send welcome message
    TelegramBotLens.send_message(chat_id, "🚀 *Telegram Group Management Features Demo*\n\nThis example will demonstrate various group management capabilities using real operations.", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Run all demonstrations
    demonstrate_member_management(chat_id, user_id: user_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_permission_management(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_content_moderation(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_spam_protection(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_group_settings(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_channel_post_management(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_admin_logging(chat_id, delay: delay)
    Process.sleep(delay * 2)

    demonstrate_utility_functions(chat_id, delay: delay)
    Process.sleep(delay * 2)

    # Send completion message
    TelegramBotLens.send_message(chat_id, "✅ *Group Management Features Demo Completed*\n\nAll examples have been demonstrated with real operations.", %{parse_mode: "Markdown"})
  end

  @doc """
  Demonstrates member management features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:user_id`: ID of a user to use for member management examples (required)
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_member_management(chat_id, opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    delay = Keyword.get(opts, :delay, 1000)

    unless user_id do
      raise "user_id is required for member management examples"
    end

    TelegramBotLens.send_message(chat_id, "🧑‍💼 *Member Management Examples*\n\nDemonstrating member management features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Restrict a user
    TelegramBotLens.send_message(chat_id, "1️⃣ Restricting user #{user_id} from sending messages for 30 seconds...")
    Process.sleep(delay)

    permissions = %{
      can_send_messages: false,
      can_send_media_messages: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false
    }

    case GroupMgmt.restrict_chat_member(chat_id, user_id, permissions, %{until_date: :os.system_time(:second) + 30}) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ User restricted successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to restrict user: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Promote a user
    TelegramBotLens.send_message(chat_id, "2️⃣ Promoting user #{user_id} to admin...")
    Process.sleep(delay)

    case GroupMgmt.promote_chat_member(chat_id, user_id, %{
      can_delete_messages: true,
      can_restrict_members: true,
      can_promote_members: false,
      can_change_info: true,
      can_invite_users: true,
      can_pin_messages: true
    }) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ User promoted to admin successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to promote user: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Set custom admin title
    TelegramBotLens.send_message(chat_id, "3️⃣ Setting custom admin title for user #{user_id}...")
    Process.sleep(delay)

    case GroupMgmt.set_chat_administrator_custom_title(chat_id, user_id, "Test Admin") do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Custom admin title set successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to set custom title: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Ban a user
    TelegramBotLens.send_message(chat_id, "4️⃣ Banning user #{user_id}...")
    Process.sleep(delay)

    case GroupMgmt.ban_chat_member(chat_id, user_id, %{until_date: :os.system_time(:second) + 60}) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ User banned successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to ban user: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Unban a user
    TelegramBotLens.send_message(chat_id, "5️⃣ Unbanning user #{user_id}...")
    Process.sleep(delay)

    case GroupMgmt.unban_chat_member(chat_id, user_id) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ User unbanned successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to unban user: #{inspect(error)}")
    end
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Member management examples completed with real operations.")
  end

  @doc """
  Demonstrates permission management features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_permission_management(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "🔒 *Permission Management Examples*\n\nDemonstrating permission management features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Set default chat permissions
    TelegramBotLens.send_message(chat_id, "1️⃣ Setting default chat permissions...")
    Process.sleep(delay)

    permissions = %{
      can_send_messages: true,
      can_send_media_messages: true,
      can_send_polls: true,
      can_send_other_messages: true,
      can_add_web_page_previews: true,
      can_change_info: false,
      can_invite_users: true,
      can_pin_messages: false
    }

    case GroupMgmt.set_chat_permissions(chat_id, permissions) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Default chat permissions set successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to set default permissions: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Create chat invite link with admin approval
    TelegramBotLens.send_message(chat_id, "2️⃣ Creating a chat invite link with admin approval...")
    Process.sleep(delay)

    case GroupMgmt.create_chat_invite_link(chat_id, %{
      name: "Test Invite (Admin Approval)",
      expire_date: :os.system_time(:second) + 3600,
      creates_join_request: true
    }) do
      {:ok, invite_link} ->
        TelegramBotLens.send_message(chat_id, "✅ Chat invite link created successfully!\nLink: #{invite_link["invite_link"]}")

        # Store the invite link for later use
        Process.put(:last_invite_link, invite_link["invite_link"])
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to create invite link: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Create regular chat invite link
    TelegramBotLens.send_message(chat_id, "3️⃣ Creating a regular chat invite link with member limit...")
    Process.sleep(delay)

    case GroupMgmt.create_chat_invite_link(chat_id, %{
      name: "Test Invite (Limited)",
      expire_date: :os.system_time(:second) + 3600,
      member_limit: 5,
      creates_join_request: false
    }) do
      {:ok, invite_link} ->
        TelegramBotLens.send_message(chat_id, "✅ Limited invite link created successfully!\nLink: #{invite_link["invite_link"]}")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to create limited invite link: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Edit invite link if we have one
    case Process.get(:last_invite_link) do
      nil ->
        TelegramBotLens.send_message(chat_id, "⚠️ Skipping invite link editing as no previous link was created.")
      invite_link ->
        TelegramBotLens.send_message(chat_id, "4️⃣ Editing the chat invite link...")
        Process.sleep(delay)

        case GroupMgmt.edit_chat_invite_link(chat_id, invite_link, %{
          name: "Updated Test Invite",
          expire_date: :os.system_time(:second) + 7200,
          creates_join_request: true
        }) do
          {:ok, edited_link} ->
            TelegramBotLens.send_message(chat_id, "✅ Chat invite link edited successfully!\nUpdated Link: #{edited_link["invite_link"]}")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to edit invite link: #{inspect(error)}")
        end
        Process.sleep(delay * 2)

        # Example: Revoke invite link
        TelegramBotLens.send_message(chat_id, "5️⃣ Revoking the chat invite link...")
        Process.sleep(delay)

        case GroupMgmt.revoke_chat_invite_link(chat_id, invite_link) do
          {:ok, _revoked_link} ->
            TelegramBotLens.send_message(chat_id, "✅ Chat invite link revoked successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to revoke invite link: #{inspect(error)}")
        end
    end
    Process.sleep(delay * 2)

    # Example: Note about join requests
    TelegramBotLens.send_message(chat_id, "6️⃣ About join requests...")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "ℹ️ When users request to join via an invite link with admin approval, you can approve or decline their requests using:\n\n```elixir\nGroupMgmt.approve_chat_join_request(chat_id, user_id)\nGroupMgmt.decline_chat_join_request(chat_id, user_id)\n```", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Permission management examples completed with real operations.")
  end

  @doc """
  Demonstrates content moderation features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_content_moderation(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "🛡️ *Content Moderation Examples*\n\nDemonstrating content moderation features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Send a test message to delete
    TelegramBotLens.send_message(chat_id, "1️⃣ Sending a test message to demonstrate deletion...")
    Process.sleep(delay)

    case TelegramBotLens.send_message(chat_id, "This is a test message that will be deleted.") do
      {:ok, message} ->
        Process.sleep(delay)
        case GroupMgmt.delete_message(chat_id, message["message_id"]) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Message deleted successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to delete message: #{inspect(error)}")
        end
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to send test message: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Send and pin a message
    TelegramBotLens.send_message(chat_id, "2️⃣ Sending and pinning a message...")
    Process.sleep(delay)

    case TelegramBotLens.send_message(chat_id, "This is a test message that will be pinned.") do
      {:ok, message} ->
        Process.sleep(delay)
        case GroupMgmt.pin_chat_message(chat_id, message["message_id"], %{disable_notification: true}) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Message pinned successfully!")
            Process.sleep(delay * 2)
            # Unpin the message
            case GroupMgmt.unpin_chat_message(chat_id, message["message_id"]) do
              {:ok, true} ->
                TelegramBotLens.send_message(chat_id, "✅ Message unpinned successfully!")
              error ->
                TelegramBotLens.send_message(chat_id, "❌ Failed to unpin message: #{inspect(error)}")
            end
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to pin message: #{inspect(error)}")
        end
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to send test message: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Delete chat photo
    TelegramBotLens.send_message(chat_id, "3️⃣ Attempting to delete chat photo...")
    Process.sleep(delay)

    case GroupMgmt.delete_chat_photo(chat_id) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Chat photo deleted successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to delete chat photo: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Clean chat history
    TelegramBotLens.send_message(chat_id, "4️⃣ Cleaning chat history for a user...")
    Process.sleep(delay)

    case TelegramBotLens.send_message(chat_id, "This is a test message for history cleaning.") do
      {:ok, message} ->
        Process.sleep(delay)
        case GroupMgmt.delete_message(chat_id, message["message_id"]) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Message deleted successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to delete message: #{inspect(error)}")
        end
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to send test message: #{inspect(error)}")
    end
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Content moderation examples completed with real operations.")
  end

  @doc """
  Demonstrates spam protection features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_spam_protection(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "🛡️ *Spam Protection Examples*\n\nDemonstrating spam protection features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Set slow mode
    TelegramBotLens.send_message(chat_id, "1️⃣ Setting slow mode to 10 seconds...")
    Process.sleep(delay)

    case GroupMgmt.set_chat_slow_mode_delay(chat_id, 10) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Slow mode set successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to set slow mode: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Disable slow mode
    TelegramBotLens.send_message(chat_id, "2️⃣ Disabling slow mode...")
    Process.sleep(delay)

    case GroupMgmt.set_chat_slow_mode_delay(chat_id, 0) do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Slow mode disabled successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to disable slow mode: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Information about other spam protection features
    TelegramBotLens.send_message(chat_id, "3️⃣ Other spam protection features...")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "ℹ️ Telegram offers additional spam protection features that can be configured:\n\n• Message auto-delete timers\n• Protected content settings\n• Hidden members\n• Aggressive anti-spam", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Spam protection examples completed with real operations.")
  end

  @doc """
  Demonstrates group settings management features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_group_settings(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "⚙️ *Group Settings Examples*\n\nDemonstrating group settings management features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Set chat title
    TelegramBotLens.send_message(chat_id, "1️⃣ Setting chat title...")
    Process.sleep(delay)

    case GroupMgmt.set_chat_title(chat_id, "Test Group Title") do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Chat title updated successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to update chat title: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Set chat description
    TelegramBotLens.send_message(chat_id, "2️⃣ Setting chat description...")
    Process.sleep(delay)

    case GroupMgmt.set_chat_description(chat_id, "This is a test group for demonstrating group management features.") do
      {:ok, true} ->
        TelegramBotLens.send_message(chat_id, "✅ Chat description updated successfully!")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to update chat description: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Set chat photo
    TelegramBotLens.send_message(chat_id, "3️⃣ Setting chat photo...")
    Process.sleep(delay)

    photo_path = "/path/to/test_photo.jpg"
    case File.exists?(photo_path) do
      true ->
        case GroupMgmt.set_chat_photo(chat_id, photo_path) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Chat photo updated successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to update chat photo: #{inspect(error)}")
        end
      false ->
        TelegramBotLens.send_message(chat_id, "⚠️ Test photo file not found, skipping chat photo update.")
    end
    Process.sleep(delay * 2)

    # Example: Information about sticker sets
    TelegramBotLens.send_message(chat_id, "4️⃣ About chat sticker sets...")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "ℹ️ Telegram allows setting and removing chat sticker sets for groups. This requires a valid sticker set name created by @Stickers bot.", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Group settings examples completed with real operations.")
  end

  @doc """
  Demonstrates channel post management features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_channel_post_management(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "📢 *Channel Post Management Examples*\n\nDemonstrating channel post management features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Send a channel post
    TelegramBotLens.send_message(chat_id, "1️⃣ Sending a channel post...")
    Process.sleep(delay)

    case TelegramBotLens.send_message(chat_id, "This is a test channel post that will be edited and deleted.", %{
      disable_notification: true
    }) do
      {:ok, message} ->
        TelegramBotLens.send_message(chat_id, "✅ Channel post sent successfully!")
        Process.sleep(delay * 2)

        # Example: Edit the channel post
        TelegramBotLens.send_message(chat_id, "2️⃣ Editing the channel post...")
        Process.sleep(delay)

        case TelegramBotLens.edit_message_text(chat_id, message["message_id"], "This is the edited version of the test channel post.") do
          {:ok, _} ->
            TelegramBotLens.send_message(chat_id, "✅ Channel post edited successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to edit channel post: #{inspect(error)}")
        end
        Process.sleep(delay * 2)

        # Example: Pin the channel post
        TelegramBotLens.send_message(chat_id, "3️⃣ Pinning the channel post...")
        Process.sleep(delay)

        case GroupMgmt.pin_chat_message(chat_id, message["message_id"], %{disable_notification: true}) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Channel post pinned successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to pin channel post: #{inspect(error)}")
        end
        Process.sleep(delay * 2)

        # Example: Unpin the channel post
        TelegramBotLens.send_message(chat_id, "4️⃣ Unpinning the channel post...")
        Process.sleep(delay)

        case GroupMgmt.unpin_chat_message(chat_id, message["message_id"]) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Channel post unpinned successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to unpin channel post: #{inspect(error)}")
        end
        Process.sleep(delay * 2)

        # Example: Delete the channel post
        TelegramBotLens.send_message(chat_id, "5️⃣ Deleting the channel post...")
        Process.sleep(delay)

        case GroupMgmt.delete_message(chat_id, message["message_id"]) do
          {:ok, true} ->
            TelegramBotLens.send_message(chat_id, "✅ Channel post deleted successfully!")
          error ->
            TelegramBotLens.send_message(chat_id, "❌ Failed to delete channel post: #{inspect(error)}")
        end

      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to send channel post: #{inspect(error)}")
    end
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Channel post management examples completed with real operations.")
  end

  @doc """
  Demonstrates admin logging features.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_admin_logging(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "📝 *Admin Logging Examples*\n\nDemonstrating admin logging features with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Get chat administrators
    TelegramBotLens.send_message(chat_id, "1️⃣ Getting chat administrators...")
    Process.sleep(delay)

    case GroupMgmt.get_chat_administrators(chat_id) do
      {:ok, admins} ->
        admin_list = Enum.map_join(admins, "\n", fn admin ->
          "- #{admin["user"]["first_name"]} (#{admin["status"]})"
        end)
        TelegramBotLens.send_message(chat_id, "✅ Chat administrators:\n#{admin_list}")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to get chat administrators: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Create admin log channel
    TelegramBotLens.send_message(chat_id, "2️⃣ Setting up admin logging...")
    Process.sleep(delay)

    case GroupMgmt.create_admin_log_channel(chat_id, "Admin Log Channel") do
      {:ok, log_channel} ->
        TelegramBotLens.send_message(chat_id, "✅ Admin log channel created successfully! Channel ID: #{log_channel["id"]}")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to create admin log channel: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Information about admin logging
    TelegramBotLens.send_message(chat_id, "3️⃣ About admin logging...")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "ℹ️ Admin logging allows you to track administrative actions in your group. Actions that can be logged include:\n\n• Message deletions\n• Member restrictions\n• Permission changes\n• Group setting updates", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Admin logging examples completed with real operations.")
  end

  @doc """
  Demonstrates utility functions.

  ## Parameters

  - `chat_id`: The ID of the chat to use for the demonstration
  - `opts`: Additional options
    - `:delay`: Delay between actions in milliseconds
  """
  def demonstrate_utility_functions(chat_id, opts \\ []) do
    delay = Keyword.get(opts, :delay, 1000)

    TelegramBotLens.send_message(chat_id, "🔧 *Utility Functions Examples*\n\nDemonstrating utility functions with real operations...", %{parse_mode: "Markdown"})
    Process.sleep(delay)

    # Example: Get chat info using TelegramBotLens
    TelegramBotLens.send_message(chat_id, "1️⃣ Getting chat information...")
    Process.sleep(delay)

    case TelegramBotLens.get_chat(chat_id) do
      {:ok, chat_info} ->
        info_text = """
        Chat Information:
        - Title: #{chat_info["title"]}
        - Type: #{chat_info["type"]}
        - Description: #{chat_info["description"] || "N/A"}
        """
        TelegramBotLens.send_message(chat_id, "✅ #{info_text}")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to get chat information: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Get chat invite link
    TelegramBotLens.send_message(chat_id, "2️⃣ Getting chat invite link...")
    Process.sleep(delay)

    case GroupMgmt.export_chat_invite_link(chat_id) do
      {:ok, invite_link} ->
        TelegramBotLens.send_message(chat_id, "✅ Chat invite link: #{invite_link}")
      error ->
        TelegramBotLens.send_message(chat_id, "❌ Failed to get invite link: #{inspect(error)}")
    end
    Process.sleep(delay * 2)

    # Example: Leave chat
    TelegramBotLens.send_message(chat_id, "3️⃣ Testing leave chat functionality (skipping actual leave)...")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "ℹ️ Skipping leave_chat call to maintain bot presence.\nTo leave a chat, use: GroupMgmt.leave_chat(chat_id)")
    Process.sleep(delay)

    TelegramBotLens.send_message(chat_id, "✅ Utility functions examples completed with real operations.")
  end
end
