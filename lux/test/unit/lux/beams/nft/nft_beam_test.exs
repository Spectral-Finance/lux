defmodule Lux.Beams.NftBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Nft.NftAggregationBeam

  describe "NftAggregationBeam" do
    test "defines beam structure and schema correctly" do
      assert NftAggregationBeam.name() == "NFT Marketplace Aggregation Beam"
      assert is_map(NftAggregationBeam.input_schema())
      assert is_map(NftAggregationBeam.output_schema())
    end
  end
end
