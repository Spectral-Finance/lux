defmodule Lux.Prisms.YouTube.ScriptGeneratorTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ScriptGenerator

  setup do
    name = :"script_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = ScriptGenerator.start_link(name: name)
    %{pid: pid}
  end

  test "generate tutorial script", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{title: "Learn Elixir", topic: "Elixir", template: :tutorial})
    assert script.title == "Learn Elixir"
    assert length(script.sections) == 5
    assert script.total_duration > 0
    assert script.language == "en"
  end

  test "generate review script", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{title: "iPhone Review", topic: "iPhone 17", template: :review})
    assert length(script.sections) == 5
    assert hd(script.sections).name == "Hook"
  end

  test "script interpolation", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{topic: "Rust"})
    assert Enum.any?(script.sections, fn s -> String.contains?(s.content, "Rust") end)
  end

  test "get script by id", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{topic: "Test"})
    {:ok, found} = ScriptGenerator.get_script(pid, script.id)
    assert found.id == script.id
  end

  test "get unknown script returns error", %{pid: pid} do
    assert {:error, :not_found} = ScriptGenerator.get_script(pid, "nonexistent")
  end

  test "add custom template", %{pid: pid} do
    {:ok, t} = ScriptGenerator.add_template(pid, %{
      name: :shorts,
      sections: [%{name: "Content", duration_seconds: 60, content_template: "Quick tip about {{topic}}", notes: "Keep it fast"}]
    })
    assert t.name == :shorts
    {:ok, templates} = ScriptGenerator.list_templates(pid)
    assert Enum.any?(templates, &(&1.name == :shorts))
  end

  test "translate script", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{title: "Hello", topic: "AI"})
    {:ok, translated} = ScriptGenerator.translate(pid, script.id, "zh")
    assert translated.language == "zh"
    assert String.starts_with?(translated.title, "[zh]")
  end

  test "generate tags from topic", %{pid: pid} do
    {:ok, script} = ScriptGenerator.generate(pid, %{topic: "Machine Learning Basics"})
    assert length(script.tags) == 3
  end
end
