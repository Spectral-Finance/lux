defmodule Lux.Prisms.Twitter.AutoReplyTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.AutoReply

  setup do
    name = :"reply_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = AutoReply.start_link(name: name, cooldown_seconds: 1)
    %{pid: pid}
  end

  test "add template and find matching reply", %{pid: pid} do
    {:ok, _} = AutoReply.add_template(pid, %{
      keywords: ["help", "support"],
      reply_text: "Hi {{author}}, how can I help?"
    })

    {:ok, reply} = AutoReply.find_reply(pid, %{
      text: "I need help with this",
      author_id: "u1",
      author_name: "Alice",
      id: "t1"
    })

    assert reply.reply_text == "Hi Alice, how can I help?"
  end

  test "no match returns nil", %{pid: pid} do
    {:ok, _} = AutoReply.add_template(pid, %{keywords: ["crypto"], reply_text: "Crypto!"})
    {:ok, reply} = AutoReply.find_reply(pid, %{text: "I love cooking", author_id: "u1", id: "t1"})
    assert reply == nil
  end

  test "blocked user gets no reply", %{pid: pid} do
    {:ok, _} = AutoReply.add_template(pid, %{keywords: ["hello"], reply_text: "Hi!"})
    :ok = AutoReply.block_user(pid, "spammer")
    {:ok, reply} = AutoReply.find_reply(pid, %{text: "hello", author_id: "spammer", id: "t1"})
    assert reply == nil
  end

  test "cooldown prevents rapid replies", %{pid: pid} do
    {:ok, _} = AutoReply.add_template(pid, %{keywords: ["test"], reply_text: "Reply!"})
    {:ok, r1} = AutoReply.find_reply(pid, %{text: "test 1", author_id: "u1", id: "t1"})
    assert r1 != nil
    {:ok, r2} = AutoReply.find_reply(pid, %{text: "test 2", author_id: "u1", id: "t2"})
    assert r2 == nil  # cooldown active
  end

  test "template variable substitution", %{pid: pid} do
    {:ok, _} = AutoReply.add_template(pid, %{
      keywords: ["thanks"],
      reply_text: "You're welcome, @{{username}}!"
    })
    {:ok, reply} = AutoReply.find_reply(pid, %{
      text: "thanks so much!",
      author_id: "u1",
      author_username: "alice_dev",
      id: "t1"
    })
    assert reply.reply_text == "You're welcome, @alice_dev!"
  end

  test "remove template", %{pid: pid} do
    {:ok, t} = AutoReply.add_template(pid, %{keywords: ["x"], reply_text: "y"})
    :ok = AutoReply.remove_template(pid, t.id)
    {:ok, templates} = AutoReply.list_templates(pid)
    assert templates == []
  end
end
