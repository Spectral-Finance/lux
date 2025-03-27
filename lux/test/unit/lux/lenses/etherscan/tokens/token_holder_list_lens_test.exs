defmodule Lux.Lenses.Etherscan.TokenHolderListLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TokenHolderList

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: true
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with default pagination" do
      # Set up the test parameters
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
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
        assert query["action"] == "tokenholderlist"
        assert query["contractaddress"] == "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "TokenHolderAddress" => "0x123456789abcdef123456789abcdef123456789a",
              "TokenHolderQuantity" => "1000000000000000000000000",
              "TokenHolderShare" => "10.00%"
            },
            %{
              "TokenHolderAddress" => "0x987654321abcdef987654321abcdef987654321a",
              "TokenHolderQuantity" => "500000000000000000000000",
              "TokenHolderShare" => "5.00%"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenHolderList.focus(params)

      # Verify the result
      assert {:ok, %{result: holders, token_holders: holders}} = result
      assert length(holders) == 2

      # Verify first holder's data
      first_holder = Enum.at(holders, 0)
      assert first_holder.address == "0x123456789abcdef123456789abcdef123456789a"
      assert first_holder.quantity == "1000000000000000000000000"
      assert first_holder.share == "10.00%"

      # Verify second holder's data
      second_holder = Enum.at(holders, 1)
      assert second_holder.address == "0x987654321abcdef987654321abcdef987654321a"
      assert second_holder.quantity == "500000000000000000000000"
      assert second_holder.share == "5.00%"
    end

    test "makes correct API call with custom pagination" do
      # Set up the test parameters
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        page: 2,
        offset: 20,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["page"] == "2"
        assert query["offset"] == "20"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "TokenHolderAddress" => "0x123456789abcdef123456789abcdef123456789a",
              "TokenHolderQuantity" => "1000000000000000000000000",
              "TokenHolderShare" => "10.00%"
            }
          ]
        })
      end)

      # Call the lens
      result = TokenHolderList.focus(params)

      # Verify the result
      assert {:ok, %{result: holders}} = result
      assert length(holders) == 1
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
      result = TokenHolderList.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid contract address format"}} = result
    end

    test "handles empty results" do
      # Set up the test parameters
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty result
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      # Call the lens
      result = TokenHolderList.focus(params)

      # Verify the result
      assert {:ok, %{result: holders, token_holders: holders}} = result
      assert holders == []
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        chainid: 1
      }

      # Update the configuration to indicate no Pro API key
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Expect an ArgumentError to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        TokenHolderList.focus(params)
      end
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with defaults" do
      # Temporarily set Pro API key to true for this test
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      # Set up the test parameters without page and offset
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        chainid: 1
      }

      # Call the function
      result = TokenHolderList.before_focus(params)

      # Verify the result
      assert result.module == "token"
      assert result.action == "tokenholderlist"
      assert result.contractaddress == "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"
      assert result.page == 1
      assert result.offset == 10
      assert result.chainid == 1
    end

    test "prepares parameters correctly with custom values" do
      # Temporarily set Pro API key to true for this test
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: true
      ])

      # Set up the test parameters with page and offset
      params = %{
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        page: 2,
        offset: 20,
        chainid: 1
      }

      # Call the function
      result = TokenHolderList.before_focus(params)

      # Verify the result
      assert result.module == "token"
      assert result.action == "tokenholderlist"
      assert result.contractaddress == "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"
      assert result.page == 2
      assert result.offset == 20
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
        contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        TokenHolderList.before_focus(params)
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
            "TokenHolderAddress" => "0x123456789abcdef123456789abcdef123456789a",
            "TokenHolderQuantity" => "1000000000000000000000000",
            "TokenHolderShare" => "10.00%"
          },
          %{
            "TokenHolderAddress" => "0x987654321abcdef987654321abcdef987654321a",
            "TokenHolderQuantity" => "500000000000000000000000",
            "TokenHolderShare" => "5.00%"
          }
        ]
      }

      # Call the function
      result = TokenHolderList.after_focus(response)

      # Verify the result
      assert {:ok, %{result: holders, token_holders: holders}} = result
      assert length(holders) == 2

      # Verify first holder's data
      first_holder = Enum.at(holders, 0)
      assert first_holder.address == "0x123456789abcdef123456789abcdef123456789a"
      assert first_holder.quantity == "1000000000000000000000000"
      assert first_holder.share == "10.00%"

      # Verify second holder's data
      second_holder = Enum.at(holders, 1)
      assert second_holder.address == "0x987654321abcdef987654321abcdef987654321a"
      assert second_holder.quantity == "500000000000000000000000"
      assert second_holder.share == "5.00%"
    end

    test "processes empty result" do
      # Create a mock response with empty result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      # Call the function
      result = TokenHolderList.after_focus(response)

      # Verify the result
      assert {:ok, %{result: holders, token_holders: holders}} = result
      assert holders == []
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid contract address format"
      }

      # Call the function
      result = TokenHolderList.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid contract address format"}} = result
    end
  end
end
