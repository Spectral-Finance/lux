defmodule Lux.Specter.RunnerTest do
  use ExUnit.Case, async: false
  import Mox

  setup :verify_on_exit!
  setup :set_mox_from_context

  setup do
    specter = %Lux.Specter{
      id: "test_specter",
      name: "Test Specter",
      description: "A test specter",
      goal: "To help with testing",
      llm_config: []
    }

    # Set up global mock behavior
    Mox.stub_with(Lux.LLM.OpenAIMock, Lux.LLM.OpenAI)
    Mox.set_mox_global(Lux.LLM.OpenAIMock)

    # Start the runner process
    {:ok, pid} = Lux.Specter.Runner.start_link(specter)
    Process.unlink(pid)

    {:ok, %{pid: pid, specter: specter}}
  end

  test "chat interaction works", %{pid: pid} do
    # Set up mock expectation for the first message
    expect(Lux.LLM.OpenAIMock, :call, fn prompt, _tools, _opts ->
      assert String.contains?(prompt, "You are Test Specter")
      assert String.contains?(prompt, "To help with testing")
      assert String.contains?(prompt, "Hi")

      {:ok,
       %Lux.Signal{
         schema_id: Lux.LLM.ResponseSchema,
         payload: %{content: "Hello! How can I help you today?"}
       }}
    end)

    assert {:ok, "Hello! How can I help you today?"} = GenServer.call(pid, {:chat, "Hi"})
  end

  test "chat maintains history", %{pid: pid} do
    # Set up mock expectation for the first message
    expect(Lux.LLM.OpenAIMock, :call, fn prompt, _tools, _opts ->
      assert String.contains?(prompt, "Hi")
      {:ok, %Lux.Signal{schema_id: Lux.LLM.ResponseSchema, payload: %{content: "Hello!"}}}
    end)

    # Set up mock expectation for the second message
    expect(Lux.LLM.OpenAIMock, :call, fn prompt, _tools, _opts ->
      assert String.contains?(prompt, "Hi")
      assert String.contains?(prompt, "Hello!")
      assert String.contains?(prompt, "How are you?")

      {:ok,
       %Lux.Signal{
         schema_id: Lux.LLM.ResponseSchema,
         payload: %{content: "I'm doing well, thank you!"}
       }}
    end)

    assert {:ok, "Hello!"} = GenServer.call(pid, {:chat, "Hi"})
    assert {:ok, "I'm doing well, thank you!"} = GenServer.call(pid, {:chat, "How are you?"})
  end
end
