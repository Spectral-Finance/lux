defmodule Lux.Lenses.Etherscan.AddressTokenNFTInventoryLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.AddressTokenNFTInventory

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
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "addresstokennftinventory"
        assert query["address"] == "0x123432244443b54409430979df8333f9308a6040"
        assert query["contractaddress"] == "0xed5af388653567af2f388e6224dc7c4b3241c544"
        assert query["page"] == "1"
        assert query["offset"] == "100"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "TokenAddress" => "0xed5af388653567af2f388e6224dc7c4b3241c544",
              "TokenName" => "Azuki",
              "TokenSymbol" => "AZUKI",
              "TokenId" => "9999",
              "TokenUri" => "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/9999"
            },
            %{
              "TokenAddress" => "0xed5af388653567af2f388e6224dc7c4b3241c544",
              "TokenName" => "Azuki",
              "TokenSymbol" => "AZUKI",
              "TokenId" => "8888",
              "TokenUri" => "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/8888"
            }
          ]
        })
      end)

      # Call the lens
      result = AddressTokenNFTInventory.focus(params)

      # Verify the result
      assert {:ok, %{result: nft_inventory, nft_inventory: nft_inventory}} = result
      assert length(nft_inventory) == 2

      # Verify first NFT token data
      first_nft = Enum.at(nft_inventory, 0)
      assert first_nft.contract_address == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert first_nft.name == "Azuki"
      assert first_nft.symbol == "AZUKI"
      assert first_nft.token_id == "9999"
      assert first_nft.token_uri == "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/9999"

      # Verify second NFT token data
      second_nft = Enum.at(nft_inventory, 1)
      assert second_nft.contract_address == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert second_nft.name == "Azuki"
      assert second_nft.symbol == "AZUKI"
      assert second_nft.token_id == "8888"
      assert second_nft.token_uri == "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/8888"
    end

    test "makes correct API call with custom pagination" do
      # Set up the test parameters
      params = %{
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        page: 2,
        offset: 50,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["page"] == "2"
        assert query["offset"] == "50"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "TokenAddress" => "0xed5af388653567af2f388e6224dc7c4b3241c544",
              "TokenName" => "Azuki",
              "TokenSymbol" => "AZUKI",
              "TokenId" => "7777",
              "TokenUri" => "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/7777"
            }
          ]
        })
      end)

      # Call the lens
      result = AddressTokenNFTInventory.focus(params)

      # Verify the result
      assert {:ok, %{result: nft_inventory}} = result
      assert length(nft_inventory) == 1
    end

    test "handles error responses" do
      # Set up the test parameters with invalid addresses
      params = %{
        address: "0xinvalid",
        contractaddress: "0xinvalid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      # Call the lens
      result = AddressTokenNFTInventory.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles rate limit error responses" do
      # Set up the test parameters
      params = %{
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
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
      result = AddressTokenNFTInventory.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Max rate limit reached, this endpoint is throttled to 2 calls/second"}} = result
    end

    test "handles empty results" do
      # Set up the test parameters
      params = %{
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
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
      result = AddressTokenNFTInventory.focus(params)

      # Verify the result
      assert {:ok, %{result: nft_inventory, nft_inventory: nft_inventory}} = result
      assert nft_inventory == []
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        chainid: 1
      }

      # Update the configuration to indicate no Pro API key
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Expect an ArgumentError to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        AddressTokenNFTInventory.focus(params)
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
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        chainid: 1
      }

      # Call the function
      result = AddressTokenNFTInventory.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "addresstokennftinventory"
      assert result.address == "0x123432244443b54409430979df8333f9308a6040"
      assert result.contractaddress == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert result.page == 1
      assert result.offset == 100
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
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        page: 2,
        offset: 50,
        chainid: 1
      }

      # Call the function
      result = AddressTokenNFTInventory.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "addresstokennftinventory"
      assert result.address == "0x123432244443b54409430979df8333f9308a6040"
      assert result.contractaddress == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert result.page == 2
      assert result.offset == 50
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
        address: "0x123432244443b54409430979df8333f9308a6040",
        contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        AddressTokenNFTInventory.before_focus(params)
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
            "TokenAddress" => "0xed5af388653567af2f388e6224dc7c4b3241c544",
            "TokenName" => "Azuki",
            "TokenSymbol" => "AZUKI",
            "TokenId" => "9999",
            "TokenUri" => "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/9999"
          },
          %{
            "TokenAddress" => "0xed5af388653567af2f388e6224dc7c4b3241c544",
            "TokenName" => "Azuki",
            "TokenSymbol" => "AZUKI",
            "TokenId" => "8888",
            "TokenUri" => "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/8888"
          }
        ]
      }

      # Call the function
      result = AddressTokenNFTInventory.after_focus(response)

      # Verify the result
      assert {:ok, %{result: nft_inventory, nft_inventory: nft_inventory}} = result
      assert length(nft_inventory) == 2

      # Verify first NFT token data
      first_nft = Enum.at(nft_inventory, 0)
      assert first_nft.contract_address == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert first_nft.name == "Azuki"
      assert first_nft.symbol == "AZUKI"
      assert first_nft.token_id == "9999"
      assert first_nft.token_uri == "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/9999"

      # Verify second NFT token data
      second_nft = Enum.at(nft_inventory, 1)
      assert second_nft.contract_address == "0xed5af388653567af2f388e6224dc7c4b3241c544"
      assert second_nft.name == "Azuki"
      assert second_nft.symbol == "AZUKI"
      assert second_nft.token_id == "8888"
      assert second_nft.token_uri == "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/8888"
    end

    test "processes empty result" do
      # Create a mock response with empty result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => []
      }

      # Call the function
      result = AddressTokenNFTInventory.after_focus(response)

      # Verify the result
      assert {:ok, %{result: nft_inventory, nft_inventory: nft_inventory}} = result
      assert nft_inventory == []
    end

    test "processes rate limit error response" do
      # Create a mock rate limit error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Max rate limit reached"
      }

      # Call the function
      result = AddressTokenNFTInventory.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Max rate limit reached, this endpoint is throttled to 2 calls/second"}} = result
    end

    test "processes general error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = AddressTokenNFTInventory.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end
