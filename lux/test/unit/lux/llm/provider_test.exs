defmodule Lux.LLM.ProviderTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Provider

  defmodule MetaFixture do
    @behaviour Lux.LLM
    @behaviour Lux.LLM.Provider

    @impl Lux.LLM.Provider
    def meta do
      %{
        name: :meta_fixture,
        models: [
          %{id: "fixture-mini", input_cost_per_mtok: 1.0, output_cost_per_mtok: 2.0,
            max_context: 8_000, capabilities: [:tools, :json_mode]},
          %{id: "fixture-pro", input_cost_per_mtok: 10.0, output_cost_per_mtok: 20.0,
            max_context: 200_000, capabilities: [:tools, :streaming]}
        ]
      }
    end

    @impl Lux.LLM
    def call(_prompt, _tools, _options), do: {:error, :not_implemented}
  end

  describe "model_meta/2" do
    test "returns the metadata for the requested model" do
      meta = Provider.model_meta(MetaFixture, "fixture-pro")
      assert meta.id == "fixture-pro"
      assert meta.input_cost_per_mtok == 10.0
      assert meta.max_context == 200_000
    end

    test "falls back to the first model when no model is given" do
      assert Provider.model_meta(MetaFixture, nil).id == "fixture-mini"
    end

    test "returns nil for an unknown model" do
      refute Provider.model_meta(MetaFixture, "not-a-model")
    end
  end

  describe "meta/0 contract" do
    test "every provider meta declares name and models" do
      meta = MetaFixture.meta()
      assert is_atom(meta.name)
      assert is_list(meta.models) and meta.models != []

      for model <- meta.models do
        assert is_binary(model.id)
        assert is_number(model.input_cost_per_mtok)
        assert is_number(model.output_cost_per_mtok)
        assert is_integer(model.max_context) and model.max_context > 0
      end
    end

    test "built-in providers implement the behaviour" do
      for module <- [Lux.LLM.Anthropic, Lux.LLM.OpenAI, Lux.LLM.TogetherAI] do
        assert {:module, _} = Code.ensure_loaded(module)

        assert function_exported?(module, :meta, 0),
               "#{inspect(module)} does not export meta/0"

        meta = module.meta()
        assert is_atom(meta.name)
        assert meta.models != []
      end
    end
  end
end
