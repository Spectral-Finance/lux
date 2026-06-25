defmodule Lux.NFTMarketplaceTest do
  use ExUnit.Case, async: true
  import Req.Test

  alias Lux.Integrations.NFTMarketplace
  alias Lux.Prisms.NFTMarketplace.GetCollectionStats

  setup do
    # Configure the integration module to run in test mock mode using Req.Test plug
    Application.put_env(:lux, NFTMarketplace, plug: {Req.Test, NFTMarketplace})

    # Register stub plug for the integration module mock supporting pattern matching
    Req.Test.stub(NFTMarketplace, fn conn ->
      path = conn.request_path
      cond do
        String.starts_with?(path, "/api/v2/collections/") and String.ends_with?(path, "/stats") ->
          # Extract slug
          slug = String.replace(path, ~r"^/api/v2/collections/|/stats$", "")
          floor = get_mock_floor(slug, :opensea)
          Req.Test.json(conn, %{
            "floor_price" => floor,
            "total_supply" => 10000,
            "num_owners" => 5400,
            "volume" => %{"1d" => 150.5},
            "average_price" => floor + 0.1
          })

        String.starts_with?(path, "/v1/collections/") and not String.ends_with?(path, "/listings") and not String.ends_with?(path, "/sales") ->
          slug = String.replace(path, "/v1/collections/", "")
          floor = get_mock_floor(slug, :blur)
          Req.Test.json(conn, %{
            "collection" => %{
              "floorPrice" => %{"amount" => to_string(floor)},
              "volume24h" => %{"amount" => "145.5"},
              "numberOwners" => 5380,
              "totalSupply" => 10000
            }
          })

        String.starts_with?(path, "/v1/contracts/") and String.ends_with?(path, "/stats") ->
          slug = String.replace(path, ~r"^/v1/contracts/|/stats$", "")
          floor = get_mock_floor(slug, :x2y2)
          Req.Test.json(conn, %{
            "data" => %{
              "floor_price" => to_string(floor),
              "volume_24h" => "155.0",
              "num_owners" => 5410,
              "total_supply" => 10000
            }
          })

        true ->
          Plug.Conn.send_resp(conn, 404, "not found")
      end
    end)

    on_exit(fn ->
      Application.delete_env(:lux, NFTMarketplace)
    end)

    :ok
  end

  # Helper to return mock floors matching NFTMarketplace behavior
  defp get_mock_floor(slug, marketplace) do
    floor_mod =
      case marketplace do
        :opensea -> 0.0
        :blur -> -0.05
        :x2y2 -> 0.03
      end

    base_floor =
      case String.downcase(slug) do
        "boredapeyachtclub" -> 22.5
        "pudgypenguins" -> 9.5
        "azuki" -> 5.2
        _ -> 15.2
      end

    Float.round(base_floor + floor_mod, 2)
  end

  test "calculates rarity correctly based on traits frequency with string and atom keys" do
    traits_data = %{
      "total_supply" => 100,
      "traits" => %{
        "Background" => %{"Red" => 80, "Gold" => 20},
        "Hat" => %{"Cap" => 90, "Crown" => 10}
      },
      "tokens" => [
        %{"token_id" => "1", "traits" => %{"Background" => "Red", "Hat" => "Cap"}},
        %{token_id: 2, traits: %{Background: "Gold", Hat: "Crown"}}
      ]
    }

    {:ok, result} = NFTMarketplace.calculate_rarity("test-collection", traits_data)

    assert result["collection"] == "test-collection"
    assert length(result["tokens"]) == 2

    [rare, common] = result["tokens"]
    assert rare["token_id"] == "2"
    assert rare["rarity_rank"] == 1
    assert rare["rarity_score"] == 15.0

    assert common["token_id"] == "1"
    assert common["rarity_rank"] == 2
    assert common["rarity_score"] == 2.36
  end

  test "compares marketplaces and selects best option" do
    {:ok, result} = NFTMarketplace.compare_marketplaces("boredapeyachtclub")
    
    assert result["collection"] == "boredapeyachtclub"
    assert result["best_buy"] == "blur"
    assert result["best_sell"] == "x2y2"
  end

  test "prism handler retrieves stats successfully supporting string parameter keys" do
    agent = %{name: "TestAgent"}
    {:ok, stats} = GetCollectionStats.handler(%{"collection_slug" => "pudgypenguins", "marketplace" => "opensea"}, agent)
    
    assert stats["collection"] == "pudgypenguins"
    assert stats["marketplace"] == "opensea"
    assert stats["floor_price"] == 9.5
  end

  test "real path normalization via Req.Test mock" do
    {:ok, os_stats} = NFTMarketplace.get_collection_stats("mock-opensea", :opensea)
    assert os_stats["floor_price"] == 15.2
    assert os_stats["marketplace"] == "opensea"

    {:ok, blur_stats} = NFTMarketplace.get_collection_stats("mock-blur", :blur)
    assert blur_stats["floor_price"] == 15.15  # 15.2 - 0.05
    assert blur_stats["marketplace"] == "blur"

    {:ok, x2y2_stats} = NFTMarketplace.get_collection_stats("mock-x2y2", :x2y2)
    assert x2y2_stats["floor_price"] == 15.23  # 15.2 + 0.03
    assert x2y2_stats["marketplace"] == "x2y2"
  end
end
