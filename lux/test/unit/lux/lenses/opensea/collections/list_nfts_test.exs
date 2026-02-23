defmodule Lux.Lenses.OpenSea.Collections.ListNFTsTest do
  @moduledoc """
  Test suite for the OpenSea ListNFTs lens.
  Verifies:
  - Paginated NFT listing with trait data
  - Empty collection handling
  - Pagination cursor propagation
  - Rarity rank inclusion
  - Error response handling
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.Collections.ListNFTs

  @collection_slug "boredapeyachtclub"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists NFTs with traits" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, @collection_slug)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "nfts" => [
            %{
              "identifier" => "1",
              "name" => "Bored Ape #1",
              "description" => "A unique ape",
              "image_url" => "https://example.com/ape1.png",
              "opensea_url" => "https://opensea.io/assets/ethereum/0x.../1",
              "updated_at" => "2024-01-15T12:00:00.000Z",
              "is_suspicious" => false,
              "rarity" => %{"rank" => 3721, "strategy_id" => "openrarity"},
              "traits" => [
                %{"trait_type" => "Background", "value" => "Blue", "trait_count" => 1152},
                %{"trait_type" => "Fur", "value" => "Brown", "trait_count" => 890}
              ]
            },
            %{
              "identifier" => "2",
              "name" => "Bored Ape #2",
              "image_url" => "https://example.com/ape2.png",
              "traits" => []
            }
          ],
          "next" => "page_cursor_xyz"
        }))
      end)

      assert {:ok, result} = ListNFTs.focus(%{"collection_slug" => @collection_slug}, %{})

      assert length(result.nfts) == 2
      assert result.next_cursor == "page_cursor_xyz"

      [nft1, nft2] = result.nfts
      assert nft1.identifier == "1"
      assert nft1.name == "Bored Ape #1"
      assert nft1.rarity_rank == 3721
      assert nft1.rarity_strategy_id == "openrarity"
      assert length(nft1.traits) == 2

      trait1 = hd(nft1.traits)
      assert trait1.trait_type == "Background"
      assert trait1.value == "Blue"
      assert trait1.trait_count == 1152

      assert nft2.identifier == "2"
      assert nft2.traits == []
      refute Map.has_key?(nft2, :rarity_rank)
    end

    test "handles empty collection" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "nfts" => [],
          "next" => nil
        }))
      end)

      assert {:ok, result} = ListNFTs.focus(%{"collection_slug" => @collection_slug}, %{})
      assert result.nfts == []
      assert result.next_cursor == nil
    end

    test "propagates pagination cursor" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "nfts" => [%{"identifier" => "100", "traits" => []}],
          "next" => "next_page_token"
        }))
      end)

      assert {:ok, result} =
               ListNFTs.focus(
                 %{"collection_slug" => @collection_slug, "limit" => 1},
                 %{}
               )

      assert result.next_cursor == "next_page_token"
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "detail" => "Collection not found"
        }))
      end)

      assert {:error, %{detail: "Collection not found"}} =
               ListNFTs.focus(%{"collection_slug" => "nonexistent"}, %{})
    end

    test "handles rate limit error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "detail" => "Request was throttled."
        }))
      end)

      assert {:error, %{detail: "Request was throttled."}} =
               ListNFTs.focus(%{"collection_slug" => @collection_slug}, %{})
    end
  end
end
