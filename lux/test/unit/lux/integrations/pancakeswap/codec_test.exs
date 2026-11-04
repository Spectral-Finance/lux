defmodule Lux.Integrations.PancakeSwap.CodecTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap.Codec

  @owner "0x00000000000000000000000000000000000000aa"
  @token "0x00000000000000000000000000000000000000bb"

  describe "selector/1" do
    test "matches well known ERC-20 selectors" do
      assert Codec.to_hex(Codec.selector("transfer(address,uint256)")) == "0xa9059cbb"
      assert Codec.to_hex(Codec.selector("approve(address,uint256)")) == "0x095ea7b3"
      assert Codec.to_hex(Codec.selector("balanceOf(address)")) == "0x70a08231"
    end
  end

  describe "encode_call/2" do
    test "encodes static arguments as 32 byte words" do
      data = Codec.encode_call("transfer(address,uint256)", [@owner, 1000])

      assert Codec.to_hex(data) ==
               "0xa9059cbb" <>
                 "00000000000000000000000000000000000000000000000000000000000000aa" <>
                 "00000000000000000000000000000000000000000000000000000000000003e8"
    end

    test "encodes booleans" do
      data = Codec.encode_call("cakePerBlock(bool)", [true])
      assert binary_part(data, 4, 32) == <<0::248, 1>>
      assert byte_size(data) == 36
    end

    test "encodes dynamic address arrays with an offset" do
      data = Codec.encode_call("getAmountsOut(uint256,address[])", [7, [@owner, @token]])

      # selector + 2 head words + length word + 2 elements
      assert byte_size(data) == 4 + 64 + 32 + 64
      assert binary_part(data, 4, 32) == <<7::256>>
      assert binary_part(data, 36, 32) == <<64::256>>
      assert binary_part(data, 68, 32) == <<2::256>>
    end

    test "accepts mixed case addresses" do
      mixed = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"

      assert Codec.encode_call("balanceOf(address)", [mixed]) ==
               Codec.encode_call("balanceOf(address)", [String.downcase(mixed)])
    end

    test "raises on invalid arguments" do
      assert_raise ArgumentError, fn -> Codec.encode_call("balanceOf(address)", ["nope"]) end
      assert_raise ArgumentError, fn -> Codec.encode_call("f(uint256)", [-1]) end
      assert_raise ArgumentError, fn -> Codec.encode_call("f(uint256)", ["1"]) end
      assert_raise ArgumentError, fn -> Codec.encode_call("f(uint256)", [1, 2]) end
    end
  end

  describe "decode/2" do
    test "decodes static values" do
      hex =
        ["uint256", "address", "bool"]
        |> Codec.encode_args([42, @owner, true])
        |> Codec.to_hex()

      assert Codec.decode(["uint256", "address", "bool"], hex) == {:ok, [42, @owner, true]}
    end

    test "decodes dynamic arrays" do
      hex = ["uint256[]"] |> Codec.encode_args([[1, 2, 3]]) |> Codec.to_hex()
      assert Codec.decode(["uint256[]"], hex) == {:ok, [[1, 2, 3]]}
    end

    test "decodes an empty array" do
      hex = ["uint256[]"] |> Codec.encode_args([[]]) |> Codec.to_hex()
      assert Codec.decode(["uint256[]"], hex) == {:ok, [[]]}
    end

    test "returns an error for empty results" do
      assert Codec.decode(["uint256"], "0x") == {:error, :empty_result}
    end

    test "returns an error for non hex responses" do
      assert Codec.decode(["uint256"], 5) == {:error, :invalid_response}
      assert Codec.decode(["uint256"], "0xzz") == {:error, :invalid_hex}
    end

    test "rejects arrays pointing outside the data" do
      bad = Codec.to_hex(<<1000::256>>)
      assert Codec.decode(["uint256[]"], bad) == {:error, :invalid_response}
    end
  end
end
