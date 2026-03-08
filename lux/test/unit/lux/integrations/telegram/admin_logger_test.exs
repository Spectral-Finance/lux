defmodule Lux.Integrations.Telegram.AdminLoggerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.AdminLogger

  setup do
    {:ok, pid} = AdminLogger.start_link(name: nil)
    %{pid: pid}
  end

  test "log and query actions", %{pid: pid} do
    {:ok, _id} = AdminLogger.log_action(pid, %{action: :ban, chat_id: -100, admin_id: 1, target_user_id: 2})
    {:ok, _id} = AdminLogger.log_action(pid, %{action: :restrict, chat_id: -100, admin_id: 1, target_user_id: 3})
    {:ok, _id} = AdminLogger.log_action(pid, %{action: :ban, chat_id: -200, admin_id: 5, target_user_id: 6})

    assert AdminLogger.count(pid) == 3
  end

  test "query by action type", %{pid: pid} do
    AdminLogger.log_action(pid, %{action: :ban, chat_id: -100, admin_id: 1, target_user_id: 2})
    AdminLogger.log_action(pid, %{action: :restrict, chat_id: -100, admin_id: 1, target_user_id: 3})

    {:ok, bans} = AdminLogger.query(pid, %{action: :ban})
    assert length(bans) == 1
  end

  test "query by chat_id", %{pid: pid} do
    AdminLogger.log_action(pid, %{action: :ban, chat_id: -100, admin_id: 1, target_user_id: 2})
    AdminLogger.log_action(pid, %{action: :ban, chat_id: -200, admin_id: 1, target_user_id: 3})

    {:ok, entries} = AdminLogger.query(pid, %{chat_id: -100})
    assert length(entries) == 1
  end

  test "recent returns entries in reverse order", %{pid: pid} do
    AdminLogger.log_action(pid, %{action: :ban, chat_id: -100, admin_id: 1, target_user_id: 1})
    Process.sleep(1)
    AdminLogger.log_action(pid, %{action: :restrict, chat_id: -100, admin_id: 1, target_user_id: 2})

    {:ok, recent} = AdminLogger.recent(pid, 2)
    assert hd(recent).action == :restrict  # most recent first
  end

  test "clear removes all", %{pid: pid} do
    AdminLogger.log_action(pid, %{action: :ban, chat_id: -100, admin_id: 1, target_user_id: 2})
    assert AdminLogger.count(pid) == 1
    :ok = AdminLogger.clear(pid)
    assert AdminLogger.count(pid) == 0
  end
end
