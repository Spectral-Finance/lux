defmodule Lux.LLM.RegistryTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.Registry

  defmodule FakeMod, do: nil

  setup do
    {:ok, pid} = Registry.start_link(name: :test_registry, table: :test_registry_ets)
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    %{server: :test_registry}
  end

  describe "register/3" do
    test "registers a new provider", %{server: s} do
      assert :ok = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
    end

    test "returns error on duplicate registration", %{server: s} do
      :ok = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
      assert {:error, :already_registered} = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
    end
  end

  describe "lookup/2" do
    test "returns entry for registered provider", %{server: s} do
      :ok = Registry.register(:anthropic, %{module: FakeMod, config: %{model: "claude"}}, s)
      assert {:ok, entry} = Registry.lookup(:anthropic, s)
      assert entry.name == :anthropic
      assert entry.health == :healthy
    end

    test "returns error for unknown provider", %{server: s} do
      assert {:error, :not_found} = Registry.lookup(:unknown, s)
    end
  end

  describe "update_health/3" do
    test "updates health status", %{server: s} do
      :ok = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
      assert :ok = Registry.update_health(:openai, :degraded, s)
      {:ok, entry} = Registry.lookup(:openai, s)
      assert entry.health == :degraded
    end

    test "returns error for unknown provider", %{server: s} do
      assert {:error, :not_found} = Registry.update_health(:unknown, :healthy, s)
    end
  end

  describe "list_healthy/1" do
    test "returns only healthy providers", %{server: s} do
      :ok = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
      :ok = Registry.register(:anthropic, %{module: FakeMod, config: %{}}, s)
      :ok = Registry.update_health(:anthropic, :unhealthy, s)
      {:ok, healthy} = Registry.list_healthy(s)
      names = Enum.map(healthy, & &1.name)
      assert :openai in names
      refute :anthropic in names
    end
  end

  describe "unregister/2" do
    test "removes a provider", %{server: s} do
      :ok = Registry.register(:openai, %{module: FakeMod, config: %{}}, s)
      :ok = Registry.unregister(:openai, s)
      Process.sleep(20)
      assert {:error, :not_found} = Registry.lookup(:openai, s)
    end
  end
end
