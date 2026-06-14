defmodule Lux.Prisms.Pancakeswap.PancakeswapSecurityPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Pancakeswap.PancakeswapSecurityPrism

  @safe_token "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
  @zero_address "0x0000000000000000000000000000000000000000"

  describe "handler/2" do
    test "detects blacklisted token" do
      {:ok, result} = PancakeswapSecurityPrism.run(%{
        token_address: @zero_address
      })
      assert result.is_safe == false
      assert result.score == 0
    end

    test "checks valid token" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "is_safe" => true,
        "honeypot" => false,
        "sell_tax" => 0.25,
        "buy_tax" => 0.25,
        "contract_verified" => true,
        "sandwich_risk" => "low",
        "score" => 95,
        "warnings" => []
      } end] do
        {:ok, result} = PancakeswapSecurityPrism.run(%{
          token_address: @safe_token
        })
        assert result.is_safe == true
        assert result.honeypot == false
        assert result.score >= 60
      end
    end

    test "detects honeypot token" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "is_safe" => false,
        "honeypot" => true,
        "sell_tax" => 99.0,
        "buy_tax" => 0.25,
        "contract_verified" => true,
        "sandwich_risk" => "low",
        "score" => 0,
        "warnings" => ["HONEYPOT DETECTED: Cannot sell token"]
      } end] do
        {:ok, result} = PancakeswapSecurityPrism.run(%{
          token_address: @safe_token
        })
        assert result.honeypot == true
        assert result.is_safe == false
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PancakeswapSecurityPrism.view()
      assert prism.input_schema.required == ["token_address"]
    end

    test "validates output schema" do
      prism = PancakeswapSecurityPrism.view()
      assert "is_safe" in prism.output_schema.required
      assert "honeypot" in prism.output_schema.required
      assert "score" in prism.output_schema.required
    end
  end
end