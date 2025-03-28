defmodule Lux.Lenses.Etherscan.TokenInfoLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TokenInfo

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: true
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "token"
        assert query["action"] == "tokeninfo"
        assert query["contractaddress"] == "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "contractAddress" => "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
              "tokenName" => "Example Token",
              "symbol" => "EXT",
              "divisor" => "1000000000000000000",
              "tokenType" => "ERC20",
              "totalSupply" => "1000000000000000000000000",
              "blueCheckmark" => "true",
              "description" => "Example token for testing",
              "website" => "https://example.com",
              "email" => "info@example.com",
              "blog" => "https://blog.example.com",
              "reddit" => "https://reddit.com/r/example",
              "slack" => "https://example.slack.com",
              "facebook" => "https://facebook.com/example",
              "twitter" => "https://twitter.com/example",
              "github" => "https://github.com/example",
              "telegram" => "https://t.me/example",
              "wechat" => "",
              "linkedin" => "https://linkedin.com/company/example",
              "discord" => "https://discord.gg/example",
              "whitepaper" => "https://example.com/whitepaper.pdf",
              "tokenPriceUSD" => "1.23"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenInfo.focus(params)

      # Verify the result
      assert {:ok, %{result: token_info, token_info: token_info}} = result
      assert length(token_info) == 1

      # Verify token info data
      token = Enum.at(token_info, 0)
      assert token.contract_address == "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"
      assert token.token_name == "Example Token"
      assert token.symbol == "EXT"
      assert token.token_type == "ERC20"
      assert token.total_supply == "1000000000000000000000000"
      assert token.website == "https://example.com"
      assert token.token_price_usd == "1.23"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid contract address
      params = %{
        contractaddress: "0xinvalid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid contract address format"
        })
      end)

      # Call the lens
      result = TokenInfo.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid contract address format"}} = result
    end

    test "handles rate limit error responses" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a rate limit error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Max rate limit reached"
        })
      end)

      # Call the lens
      result = TokenInfo.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Max rate limit reached, this endpoint is throttled to 2 calls/second"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
        chainid: 1
      }

      # Update the configuration to indicate no Pro API key
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Expect an ArgumentError to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        TokenInfo.focus(params)
      end
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Temporarily set Pro API key to true for this test
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      # Set up the test parameters
      params = %{
        contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
        chainid: 1
      }

      # Call the function
      result = TokenInfo.before_focus(params)

      # Verify the result
      assert result.module == "token"
      assert result.action == "tokeninfo"
      assert result.contractaddress == "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"
      assert result.chainid == 1
    end

    test "raises error when Pro API key is not available" do
      # Temporarily set Pro API key to false
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        TokenInfo.before_focus(params)
      end
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "contractAddress" => "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
            "tokenName" => "Example Token",
            "symbol" => "EXT",
            "divisor" => "1000000000000000000",
            "tokenType" => "ERC20",
            "totalSupply" => "1000000000000000000000000",
            "blueCheckmark" => "true",
            "description" => "Example token for testing",
            "website" => "https://example.com",
            "email" => "info@example.com",
            "blog" => "https://blog.example.com",
            "reddit" => "https://reddit.com/r/example",
            "slack" => "https://example.slack.com",
            "facebook" => "https://facebook.com/example",
            "twitter" => "https://twitter.com/example",
            "github" => "https://github.com/example",
            "telegram" => "https://t.me/example",
            "wechat" => "",
            "linkedin" => "https://linkedin.com/company/example",
            "discord" => "https://discord.gg/example",
            "whitepaper" => "https://example.com/whitepaper.pdf",
            "tokenPriceUSD" => "1.23"
          }
        ]
      }

      # Call the function
      result = TokenInfo.after_focus(response)

      # Verify the result
      assert {:ok, %{result: token_info, token_info: token_info}} = result
      assert length(token_info) == 1

      # Verify token info data
      token = Enum.at(token_info, 0)
      assert token.contract_address == "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"
      assert token.token_name == "Example Token"
      assert token.symbol == "EXT"
      assert token.token_type == "ERC20"
      assert token.total_supply == "1000000000000000000000000"
      assert token.website == "https://example.com"
      assert token.token_price_usd == "1.23"
    end

    test "processes empty result" do
      # Create a mock response with empty result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      # Call the function
      result = TokenInfo.after_focus(response)

      # Verify the result
      assert {:ok, %{result: token_info, token_info: token_info}} = result
      assert token_info == []
    end

    test "processes rate limit error response" do
      # Create a mock rate limit error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Max rate limit reached"
      }

      # Call the function
      result = TokenInfo.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Max rate limit reached, this endpoint is throttled to 2 calls/second"}} = result
    end

    test "processes general error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid contract address format"
      }

      # Call the function
      result = TokenInfo.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid contract address format"}} = result
    end
  end
end
