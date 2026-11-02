defmodule Lux.Integrations.Telegram.GroupManagement.AuditLoggerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.GroupManagement.AuditLogger

  describe "AuditLogger" do
    test "create_entry/3 generates structured audit log" do
      entry =
        AuditLogger.create_entry(:ban, -100_123_456,
          actor_id: 999,
          target_id: 111,
          reason: "Spam link detected"
        )

      assert entry.action == :ban
      assert entry.chat_id == -100_123_456
      assert entry.actor_id == 999
      assert entry.target_id == 111
      assert entry.reason == "Spam link detected"
      assert %DateTime{} = entry.timestamp
      assert String.starts_with?(entry.id, "audit_")
    end

    test "format_log_message/2 generates HTML and Markdown notifications" do
      entry =
        AuditLogger.create_entry(:mute, -100_999,
          actor_id: 1,
          target_id: 2,
          reason: "Excessive mass mentions"
        )

      html = AuditLogger.format_log_message(entry, :html)
      assert String.contains?(html, "<b>[AUDIT LOG - MUTE]</b>")
      assert String.contains?(html, "<code>-100999</code>")
      assert String.contains?(html, "Excessive mass mentions")

      markdown = AuditLogger.format_log_message(entry, :markdown)
      assert String.contains?(markdown, "*[AUDIT LOG - MUTE]*")
      assert String.contains?(markdown, "`-100999`")
    end

    test "filter_entries/2 filters audit entries by criteria" do
      e1 = AuditLogger.create_entry(:ban, -100, actor_id: 10, target_id: 20)
      e2 = AuditLogger.create_entry(:warn, -100, actor_id: 10, target_id: 30)
      e3 = AuditLogger.create_entry(:ban, -200, actor_id: 11, target_id: 40)

      entries = [e1, e2, e3]

      # Filter by action
      bans = AuditLogger.filter_entries(entries, %{action: :ban})
      assert length(bans) == 2

      # Filter by chat
      chat_entries = AuditLogger.filter_entries(entries, %{chat_id: -100})
      assert length(chat_entries) == 2

      # Filter by target
      target_entries = AuditLogger.filter_entries(entries, %{target_id: 20})
      assert length(target_entries) == 1
      assert hd(target_entries).id == e1.id
    end
  end
end
