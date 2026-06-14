defmodule Lux.Prisms.Sushiswap.SushiswapSecurityPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Sushiswap.SushiswapSecurityPrism

  @safe_token "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
  @zero_address "0x0000000000000000000000000000000000000000"

  describe "handler/2" do
    test "detects blacklisted token" do
      {:ok, result} = SushiswapSecurityPrism.run(%{
        token_address: @zero_address,
        chain_id: 56
      })
      assert result.is_safe == false
      assert result.score == 0
    end

    test "checks valid token" do
        "is_safe" => true,
        "honeypot" => false,
        "sell_tax" => 0.3,
        "buy_tax" => 0.3,
        "contract_verified" => true,
        "sandwich_risk" => "low",
        "score" => 95,
        "warnings" => []
      } end] do
        {:ok, result} = SushiswapSecurityPrism.run(%{
          token_address: @safe_token,
          chain_id: 56
        })
        assert result.is_safe == true
        assert result.honeypot == false
        assert result.score >= 60
      end
    end

    test "detects honeypot token" do
        "is_safe" => false,
        "honeypot" => true,
        "sell_tax" => 99.0,
        "buy_tax" => 0.3,
        "contract_verified" => true,
        "sandwich_risk" => "low",
        "score" => 0,
        "warnings" => ["HONEYPOT DETECTED: Cannot sell token"]
      } end] do
        {:ok, result} = SushiswapSecurityPrism.run(%{
          token_address: @safe_token,
          chain_id: 56
        })
        assert result.honeypot == true
        assert result.is_safe == false
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SushiswapSecurityPrism.view()
      assert prism.input_schema.required == ["token_address"]
    end

    test "validates output schema" do
      prism = SushiswapSecurityPrism.view()
      assert "is_safe" in prism.output_schema.required
      assert "honeypot" in prism.output_schema.required
      assert "score" in prism.output_schema.required
    end
  end
end