defmodule Lux.Prisms.Discord.ModerationTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation

  setup do
    name = :"mod_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = Moderation.start_link(name: name)
    %{pid: pid}
  end

  test "check clean content", %{pid: pid} do
    {:ok, result} = Moderation.check_content(pid, "Hello, how are you?")
    assert result.clean
  end

  test "detect spam link", %{pid: pid} do
    {:ok, result} = Moderation.check_content(pid, "Join my server discord.gg/abc123")
    refute result.clean
    assert length(result.violations) >= 1
  end

  test "add custom filter", %{pid: pid} do
    {:ok, filter} = Moderation.add_filter(pid, %{pattern: "badword", action: :delete, severity: :high})
    assert filter.action == :delete
    {:ok, result} = Moderation.check_content(pid, "This contains badword in it")
    refute result.clean
  end

  test "list filters", %{pid: pid} do
    {:ok, filters} = Moderation.list_filters(pid)
    assert length(filters) >= 2  # default filters
  end

  test "warn user", %{pid: pid} do
    {:ok, result} = Moderation.warn_user(pid, "user1", "Spamming")
    assert result.warning_count == 1
    {:ok, result2} = Moderation.warn_user(pid, "user1", "Toxicity")
    assert result2.warning_count == 2
  end

  test "get warnings", %{pid: pid} do
    Moderation.warn_user(pid, "user1", "Test")
    {:ok, warnings} = Moderation.get_warnings(pid, "user1")
    assert length(warnings) == 1
  end

  test "get empty warnings", %{pid: pid} do
    {:ok, warnings} = Moderation.get_warnings(pid, "unknown")
    assert warnings == []
  end

  test "action log", %{pid: pid} do
    Moderation.warn_user(pid, "user1", "Reason")
    {:ok, log} = Moderation.get_action_log(pid)
    assert length(log) == 1
    assert hd(log).action == :warn
  end

  test "regex filter", %{pid: pid} do
    {:ok, _} = Moderation.add_filter(pid, %{pattern: ~r/n[i1]gg/i, action: :ban, severity: :critical})
    {:ok, result} = Moderation.check_content(pid, "Some slur n1gg here")
    refute result.clean
  end
end
