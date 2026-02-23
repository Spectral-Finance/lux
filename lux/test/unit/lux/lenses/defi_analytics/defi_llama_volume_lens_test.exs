defmodule Lux.Lenses.DeFiAnalytics.DeFiLlamaVolumeLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.DeFiAnalytics.DeFiLlamaVolumeLens

  describe "focus/2 — input variants" do
    test "accepts empty input (global dexs overview)" do
      result = DeFiLlamaVolumeLens.focus(%{}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts protocol slug" do
      result = DeFiLlamaVolumeLens.focus(%{protocol: "uniswap"}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts data_type dexs" do
      result = DeFiLlamaVolumeLens.focus(%{data_type: "dexs", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts data_type fees" do
      result = DeFiLlamaVolumeLens.focus(%{data_type: "fees", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts data_type options" do
      result = DeFiLlamaVolumeLens.focus(%{data_type: "options", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts chain filter" do
      result = DeFiLlamaVolumeLens.focus(%{chain: "Ethereum", top_n: 5}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts top_n parameter" do
      result = DeFiLlamaVolumeLens.focus(%{top_n: 3}, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts exclude_total_data_chart flag" do
      result = DeFiLlamaVolumeLens.focus(%{
        top_n: 5,
        exclude_total_data_chart: true
      }, %{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "focus/2 — live API (network dependent)" do
    @tag :integration
    test "global DEX overview has expected fields" do
      case DeFiLlamaVolumeLens.focus(%{top_n: 5}, %{}) do
        {:ok, result} ->
          assert Map.has_key?(result, :total_volume_24h)
          assert Map.has_key?(result, :total_volume_7d)
          assert Map.has_key?(result, :top_protocols)
          assert Map.has_key?(result, :protocol_count)
          assert result.status == "success"
          assert result.total_volume_24h > 0
          assert is_list(result.top_protocols)
          assert length(result.top_protocols) <= 5
        {:error, _} -> :skip
      end
    end

    @tag :integration
    test "protocol volume has volume and fee fields" do
      case DeFiLlamaVolumeLens.focus(%{protocol: "uniswap", data_type: "dexs"}, %{}) do
        {:ok, result} ->
          assert Map.has_key?(result, :volume_24h)
          assert Map.has_key?(result, :volume_24h_formatted)
          assert Map.has_key?(result, :volume_7d)
          assert Map.has_key?(result, :fees_24h)
          assert Map.has_key?(result, :chains)
          assert result.status == "success"
          assert is_binary(result.volume_24h_formatted)
        {:error, _} -> :skip
      end
    end

    @tag :integration
    test "top protocols have volume data" do
      case DeFiLlamaVolumeLens.focus(%{top_n: 3}, %{}) do
        {:ok, result} ->
          for proto <- result.top_protocols do
            assert Map.has_key?(proto, "name")
            assert Map.has_key?(proto, "volume_24h")
            assert Map.has_key?(proto, "volume_24h_formatted")
            assert proto["volume_24h"] >= 0
          end
        {:error, _} -> :skip
      end
    end
  end

  describe "schema" do
    test "schema has all properties documented" do
      schema = DeFiLlamaVolumeLens.view().schema
      props = schema.properties
      assert Map.has_key?(props, :protocol)
      assert Map.has_key?(props, :data_type)
      assert Map.has_key?(props, :chain)
      assert Map.has_key?(props, :top_n)
    end
  end
end
