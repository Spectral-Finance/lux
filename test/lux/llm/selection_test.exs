defmodule Lux.LLM.SelectionTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  setup do
    # Ensure the mock provider is registered before the registry boots.
    Application.put_env(:lux, :llm_providers, [{:mock, Lux.LLM.MockProvider}])

    # Restart the registry with the new config.
    {:ok, _pid} = start_supervised!(Lux.LLM.ProviderRegistry)

    :ok
  end

  test "generate uses the mock provider and returns expected response" do
    assert {:ok, "Echo: hello world"} = Lux.LLM.Selection.generate("hello world")
  end

  test "fallback works when primary provider errors" do
    # Register a failing provider first, then the mock as fallback.
    defmodule FailingProvider do
      @behaviour Lux.LLM.Provider
      def name, do: :failing
      def generate(_prompt, _opts), do: {:error, :boom}
      def cost(_), do: 0
    end

    Application.put_env(:lux, :llm_providers, [
      {:failing, FailingProvider},
      {:mock, Lux.LLM.MockProvider}
    ])

    # Restart registry to pick up new list
    :ok = Supervisor.terminate_child(Lux.Supervisor, Lux.LLM.ProviderRegistry)
    {:ok, _} = Supervisor.restart_child(Lux.Supervisor, Lux.LLM.ProviderRegistry)

    assert {:ok, "Echo: test"} = Lux.LLM.Selection.generate("test", fallback: [:mock])
  end
end
