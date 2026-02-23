defmodule Lux.Lenses.OpenSea.NFTs.GetNFTTest do
  @moduledoc """
  Test suite for the OpenSea GetNFT lens.
  Verifies:
  - Single NFT metadata retrieval with traits and ownership
  - Rarity rank extraction
  - Trait transformation
  - Error handling for missing and invalid NFTs
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.OpenSea.NFTs.GetNFT

  @chain "ethereum"
  @address "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
  @identifier "1234"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves NFT with traits and rarity" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert String.contains?(conn.request_path, @chain)
        assert String.contains?(conn.request_path, @address)
        assert String.contains?(conn.request_path, @identifier)

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "nft" => %{
            "identifier" => @identifier,
            "collection" => "boredapeyachtclub",
            "contract" => @address,
            "token_standard" => "erc721",
            "name" => "Bored Ape #1234",
            "description" => "A unique ape.",
            "image_url" => "https://example.com/ape1234.png",
            "opensea_url" => "https://opensea.io/assets/ethereum/#{@address}/#{@identifier}",
            "updated_at" => "2024-01-15T12:00:00.000Z",
            "is_disabled" => false,
            "is_nsfw" => false,
            "traits" => [
              %{
                "trait_type" => "Background",
                "value" => "Blue",
                "trait_count" => 1152
              },
              %{
                "trait_type" => "Eyes",
                "value" => "Laser Eyes",
                "trait_count" => 89
              }
            ],
            "owners" => [
              %{"address" => "0xowner123", "quantity" => 1}
            ],
            "rarity" => %{
              "rank" => 2491,
              "strategy_id" => "openrarity"
            }
          }
        }))
      end)

      assert {:ok, result} = GetNFT.focus(
        %{"chain" => @chain, "address" => @address, "identifier" => @identifier},
        %{}
      )

      assert result.identifier == @identifier
      assert result.collection == "boredapeyachtclub"
      assert result.contract == @address
      assert result.name == "Bored Ape #1234"
      assert result.rarity_rank == 2491
      assert result.rarity_strategy_id == "openrarity"
      assert length(result.traits) == 2

      [trait1 | _] = result.traits
      assert trait1.trait_type == "Background"
      assert trait1.value == "Blue"
      assert trait1.trait_count == 1152

      assert length(result.owners) == 1
      assert hd(result.owners).address == "0xowner123"
    end

    test "retrieves NFT without optional fields" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "nft" => %{
            "identifier" => "1",
            "collection" => "testcollection",
            "contract" => @address,
            "traits" => [],
            "owners" => []
          }
        }))
      end)

      assert {:ok, result} = GetNFT.focus(
        %{"chain" => @chain, "address" => @address, "identifier" => "1"},
        %{}
      )

      assert result.identifier == "1"
      assert result.traits == []
      assert result.owners == []
      refute Map.has_key?(result, :rarity_rank)
      refute Map.has_key?(result, :name)
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "detail" => "NFT not found"
        }))
      end)

      assert {:error, %{detail: "NFT not found"}} =
               GetNFT.focus(
                 %{"chain" => @chain, "address" => @address, "identifier" => "9999999"},
                 %{}
               )
    end

    test "handles unauthorized error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "detail" => "Authentication credentials were not provided."
        }))
      end)

      assert {:error, %{detail: "Authentication credentials were not provided."}} =
               GetNFT.focus(
                 %{"chain" => @chain, "address" => @address, "identifier" => @identifier},
                 %{}
               )
    end
  end
end
