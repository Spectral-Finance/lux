defmodule Lux.Prisms.TvlPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.TvlPrism

  @valid_protocol "uniswap"
  @invalid_protocol "invalid_protocol_123"
  @malformed_protocol "bad-response"

  describe "handler/2" do
    test "returns TVL for valid protocol" do
      assert {:ok, result} = TvlPrism.run(%{protocol: @valid_protocol})
      assert is_number(result.tvl)
      assert result.protocol == @valid_protocol
    end

    test "handles invalid protocol slug" do
      assert {:error, error} = TvlPrism.run(%{protocol: @invalid_protocol})
      assert String.contains?(error, "HTTP error 4")  # Covers both 400 and 404
    end

    test "handles invalid response format" do
      assert {:error, error} = TvlPrism.run(%{protocol: @malformed_protocol})
      assert String.contains?(error, "Invalid TVL format") ||
             String.contains?(error, "HTTP error")
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = TvlPrism.view()
      assert prism.input_schema.required == ["protocol"]
      assert Map.has_key?(prism.input_schema.properties, :protocol)
    end

    test "validates output schema" do
      prism = TvlPrism.view()
      assert prism.output_schema.required == ["tvl", "protocol"]
      assert Map.has_key?(prism.output_schema.properties, :tvl)
      assert Map.has_key?(prism.output_schema.properties, :protocol)
    end
  end
end
