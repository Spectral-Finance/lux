defmodule Lux.LLM.RegistryTest do
  use UnitAPICase, async: false

  alias Lux.LLM.Registry

  defmodule FixtureProvider do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :registry_fixture,
        models: [
          %{id: "fixture-mini", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
            max_context: 8_000, capabilities: [:tools]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, _options), do: {:error, :not_implemented}
  end

  setup do
    start_supervised!(Registry)
    :ok
  end

  describe "register/2" do
    test "registers a provider with default weight and status" do
      :ok = Registry.register(FixtureProvider)

      assert entry = Registry.lookup(FixtureProvider)
      assert entry.module == FixtureProvider
      assert entry.status == :up
      assert entry.weight == 1.0
      assert entry.default_model == "fixture-mini"
    end

    test "honours forced model and weight config" do
      :ok = Registry.register(FixtureProvider, model: "fixture-mini", weight: 2.5, api_key: "k")

      entry = Registry.lookup(FixtureProvider)
      assert entry.weight == 2.5
      assert entry.default_model == "fixture-mini"
      assert entry.config == %{api_key: "k"}
    end

    test "re-registering replaces the entry" do
      :ok = Registry.register(FixtureProvider, weight: 1.0)
      :ok = Registry.register(FixtureProvider, weight: 9.0)

      assert Registry.lookup(FixtureProvider).weight == 9.0
    end

    test "rejects modules that are not providers" do
      assert {:error, {:not_a_provider, _}} = Registry.register(Enum)
    end
  end

  describe "list/0, available/0" do
    test "lists registered entries and filters by status" do
      :ok = Registry.register(FixtureProvider)

      assert [%{module: FixtureProvider}] = Registry.list()
      assert [%{module: FixtureProvider}] = Registry.available()

      :ok = Registry.mark_down(FixtureProvider)
      assert Registry.lookup(FixtureProvider).status == :down
      assert Registry.available() == []

      :ok = Registry.mark_up(FixtureProvider)
      assert Registry.available() != []
    end
  end

  describe "unregister/1" do
    test "removes a provider from the registry" do
      :ok = Registry.register(FixtureProvider)
      :ok = Registry.unregister(FixtureProvider)

      refute Registry.lookup(FixtureProvider)
      assert Registry.list() == []
    end
  end

  describe "lookup/1" do
    test "returns nil for unknown providers" do
      refute Registry.lookup(Unknown.Provider)
    end
  end
end
