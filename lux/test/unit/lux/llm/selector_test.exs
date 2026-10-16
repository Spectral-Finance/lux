defmodule Lux.LLM.SelectorTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Selector

  defp model(id, opts \\ []) do
    %{
      id: id,
      input_cost_per_mtok: Keyword.get(opts, :in, 3.0),
      output_cost_per_mtok: Keyword.get(opts, :out, 6.0),
      max_context: Keyword.get(opts, :context, 200_000),
      capabilities: Keyword.get(opts, :caps, [:tools, :json_mode])
    }
  end

  defp entry(module, models, opts \\ []) do
    %{
      module: module,
      config: %{},
      meta: %{name: module, models: models},
      status: Keyword.get(opts, :status, :up),
      default_model: nil,
      weight: Keyword.get(opts, :weight, 1.0)
    }
  end

  describe "rank/2" do
    test "prefers the cheapest provider with quality: :cheap" do
      expensive = entry(Expensive, [model("e-pro", in: 15.0, out: 75.0)])
      cheap = entry(Cheap, [model("c-mini", in: 0.25, out: 1.25)])

      assert [%{module: Cheap}, %{module: Expensive}] = Selector.rank([expensive, cheap], quality: :cheap)
    end

    test "prefers capability-rich providers with quality: :best" do
      basic = entry(Basic, [model("b-mini", in: 0.25, out: 0.5, caps: [:json_mode])])
      capable = entry(Capable, [model("k-pro", in: 15.0, out: 75.0, caps: [:tools, :json_mode, :streaming])])

      assert [%{module: Capable} | _] = Selector.rank([basic, capable], quality: :best)
    end

    test "filters out providers whose context is too small" do
      tiny = entry(Tiny, [model("t-mini", context: 1_000)])
      big = entry(Big, [model("b-pro", context: 200_000)])

      ranked = Selector.rank([tiny, big], prompt_tokens: 50_000)
      assert [%{module: Big}] = ranked
    end

    test "filters out down providers" do
      down = entry(Down, [model("d-pro")], status: :down)
      up = entry(Up, [model("u-pro")])

      assert [%{module: Up}] = Selector.rank([down, up], %{})
    end

    test "respects an explicit provider allow-list" do
      a = entry(A, [model("a-pro")])
      b = entry(B, [model("b-pro")])

      assert [%{module: A}] = Selector.rank([a, b], providers: [A])
    end

    test "keeps only models that support tools when tools are required" do
      no_tools = entry(NoTools, [model("nt", caps: [:json_mode])])
      with_tools = entry(WithTools, [model("wt", caps: [:tools, :json_mode])])

      ranked = Selector.rank([no_tools, with_tools], tools: [:some_prism])

      assert length(ranked) == 2
      assert [%{module: WithTools} | _] = ranked
      assert hd(ranked).config.model == "wt"
    end

    test "returns [] when nothing satisfies the requirements" do
      tiny = entry(Tiny, [model("t-mini", context: 1_000)])

      assert Selector.rank([tiny], prompt_tokens: 1_000_000) == []
    end

    test "injects the selected model into the entry config" do
      dual = entry(Dual, [model("d-cheap", in: 0.25, out: 1.25), model("d-pro", in: 15.0, out: 75.0)])

      [best] = Selector.rank([dual], quality: :cheap)
      assert best.config.model == "d-cheap"
    end
  end

  describe "select/2" do
    test "returns the single best entry" do
      cheap = entry(Cheap, [model("c-mini", in: 0.25, out: 1.25)])
      expensive = entry(Expensive, [model("e-pro", in: 15.0, out: 75.0)])

      assert %{module: Cheap} = Selector.select([expensive, cheap], quality: :cheap)
    end

    test "returns nil when there is no candidate" do
      assert Selector.select([], %{}) == nil
    end
  end
end
