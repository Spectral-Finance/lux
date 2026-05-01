ExUnit.start()

defmodule Lux.Prisms.Nft.TestHelper do
  @moduledoc """
  Test helpers for NFT prism tests.
  """

  @test_collection_slug "bored-ape-yacht-club"
  @test_collection_address "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"
  @test_token_id "1000"

  def test_collection_slug, do: @test_collection_slug
  def test_collection_address, do: @test_collection_address
  def test_token_id, do: @test_token_id
end
