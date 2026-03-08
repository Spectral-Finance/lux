defmodule Lux.Prisms.YouTube.Community.CommentManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.Community.CommentManager

  setup do
    name = :"cm_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = CommentManager.start_link(name: name)
    %{pid: pid}
  end

  test "analyze positive comment", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{id: "c1", text: "This is amazing and wonderful!", author: "Alice"})
    assert a.sentiment == :positive
    refute a.is_spam
  end

  test "analyze negative comment", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{text: "This is terrible and awful"})
    assert a.sentiment == :negative
  end

  test "detect question", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{text: "How do I install this?"})
    assert a.is_question
  end

  test "detect spam", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{text: "Check my channel for free stuff!"})
    assert a.is_spam
  end

  test "detect link", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{text: "Visit https://example.com"})
    assert a.has_link
  end

  test "detect Chinese", %{pid: pid} do
    {:ok, a} = CommentManager.analyze_comment(pid, %{text: "這個視頻太棒了"})
    assert a.language == "zh"
  end

  test "generate response for question", %{pid: pid} do
    {:ok, r} = CommentManager.generate_response(pid, %{text: "How does this work?"})
    assert r.response.action == :reply
  end

  test "generate response for spam", %{pid: pid} do
    {:ok, r} = CommentManager.generate_response(pid, %{text: "Sub4sub check my channel"})
    assert r.response.action == :hide
  end

  test "generate response for positive", %{pid: pid} do
    {:ok, r} = CommentManager.generate_response(pid, %{text: "This is excellent!"})
    assert r.response.action == :heart
  end

  test "batch analyze", %{pid: pid} do
    comments = [%{text: "Great!"}, %{text: "Terrible"}, %{text: "Normal day"}]
    {:ok, results} = CommentManager.batch_analyze(pid, comments)
    assert length(results) == 3
  end

  test "stats accumulate", %{pid: pid} do
    CommentManager.analyze_comment(pid, %{text: "Amazing!"})
    CommentManager.analyze_comment(pid, %{text: "Horrible"})
    {:ok, stats} = CommentManager.get_stats(pid)
    assert stats.total == 2
  end
end
