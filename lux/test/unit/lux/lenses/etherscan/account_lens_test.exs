defmodule Lux.Lenses.Etherscan.AccountLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.AccountLens

  # Add a delay between API calls to avoid rate limiting
  @delay_ms 300

  # Helper function to set up the API key for tests
  setup do
    # Store original API key configuration
    original_api_key = Application.get_env(:lux, :api_keys)

    # Set API key for testing from environment variable or use a default test key
    api_key = System.get_env("ETHERSCAN_API_KEY") || "YourApiKeyToken"

    # Check if we should use Pro API key for testing
    is_pro = System.get_env("ETHERSCAN_API_KEY_PRO") == "true"

    # Set the API key and Pro flag
    Application.put_env(:lux, :api_keys, [etherscan: api_key, etherscan_pro: is_pro])

    # Add a delay to avoid hitting rate limits
    Process.sleep(@delay_ms)

    on_exit(fn ->
      # Restore original API key configuration
      Application.put_env(:lux, :api_keys, original_api_key)
    end)

    :ok
  end

  # Helper function to add delay between API calls
  defp with_rate_limit(fun) do
    Process.sleep(@delay_ms)
    fun.()
  end

  # Helper function to check if a result is either successful or a Pro API error
  defp assert_success_or_pro_error(result) do
    case result do
      {:ok, %{result: _}} ->
        assert true
      {:error, %{message: "NOTOK", result: error_message}} ->
        assert error_message =~ "API Pro" or error_message =~ "Pro API"
      other ->
        flunk("Expected either a successful result or a Pro API error, got: #{inspect(other)}")
    end
  end

  describe "get_eth_balance/1" do
    @tag :integration
    test "fetches ETH balance for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045" # Vitalik's address
      }

      result = with_rate_limit(fn -> AccountLens.get_eth_balance(params) end)

      IO.puts("\n=== ETH Balance Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: balance}} = result
      assert is_binary(balance)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_eth_balance(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_eth_balance(%{address: "invalid"})
      end
    end
  end

  describe "get_eth_balance_multi/1" do
    @tag :integration
    test "fetches ETH balance for multiple addresses with real API key" do
      params = %{
        addresses: [
          "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
          "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"  # Bitfinex's address
        ]
      }

      result = with_rate_limit(fn -> AccountLens.get_eth_balance_multi(params) end)

      IO.puts("\n=== ETH Balance Multi Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: balances}} = result
      assert is_list(balances)
      assert length(balances) == 2

      # Check structure of first balance
      first_balance = List.first(balances)
      assert Map.has_key?(first_balance, "account")
      assert Map.has_key?(first_balance, "balance")
    end

    test "raises error when addresses is missing" do
      assert_raise ArgumentError, "addresses parameter is required", fn ->
        AccountLens.get_eth_balance_multi(%{})
      end
    end
  end

  describe "get_eth_balance_history/1" do
    @tag :integration
    test "fetches historical ETH balance for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        blockno: 16000000
      }

      result = with_rate_limit(fn -> AccountLens.get_eth_balance_history(params) end)

      IO.puts("\n=== ETH Balance History Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro subscription
      assert_success_or_pro_error(result)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_eth_balance_history(%{blockno: 16000000})
      end
    end

    test "raises error when blockno is missing" do
      assert_raise ArgumentError, "blockno parameter is required", fn ->
        AccountLens.get_eth_balance_history(%{address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_eth_balance_history(%{address: "invalid", blockno: 16000000})
      end
    end
  end

  describe "get_token_balance/1" do
    @tag :integration
    test "fetches token balance for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        contractaddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F" # DAI token
      }

      result = with_rate_limit(fn -> AccountLens.get_token_balance(params) end)

      IO.puts("\n=== Token Balance Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: balance}} = result
      assert is_binary(balance)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_token_balance(%{contractaddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F"})
      end
    end

    test "raises error when contractaddress is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        AccountLens.get_token_balance(%{address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_token_balance(%{
          address: "invalid",
          contractaddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F"
        })
      end
    end
  end

  describe "get_normal_transactions/1" do
    @tag :integration
    test "fetches normal transactions for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_normal_transactions(params) end)

      IO.puts("\n=== Normal Transactions Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transactions}} = result
      assert is_list(transactions)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_normal_transactions(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_normal_transactions(%{address: "invalid"})
      end
    end
  end

  describe "get_internal_transactions/1" do
    @tag :integration
    test "fetches internal transactions for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_internal_transactions(params) end)

      IO.puts("\n=== Internal Transactions Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transactions}} = result
      # Could be an empty list or a list of transactions
      assert is_list(transactions)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_internal_transactions(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_internal_transactions(%{address: "invalid"})
      end
    end
  end

  describe "get_internal_transactions_by_hash/1" do
    @tag :integration
    test "fetches internal transactions by hash with real API key" do
      with_rate_limit(fn ->
        hash = "0x3742f23b14c99c386ca59d5d6193bb23141e6e34963d735ce60d88a210f3b02a"
        result = AccountLens.get_internal_transactions_by_hash(%{txhash: hash})
        IO.puts("\n=== Internal Transactions By Hash Response ===")
        IO.puts("Result: #{inspect(result, pretty: true)}")

        # Check for either successful result or "No transactions found" message
        assert match?({:ok, %{result: _}}, result) or
               match?({:error, %{message: "No transactions found", result: []}}, result)
      end)
    end

    test "raises error when txhash is missing" do
      assert_raise ArgumentError, "txhash parameter is required", fn ->
        AccountLens.get_internal_transactions_by_hash(%{})
      end
    end

    test "raises error when txhash is invalid" do
      assert_raise ArgumentError, "Invalid transaction hash format: invalid", fn ->
        AccountLens.get_internal_transactions_by_hash(%{txhash: "invalid"})
      end
    end
  end

  describe "get_internal_transactions_by_block_range/1" do
    @tag :integration
    test "fetches internal transactions by block range with real API key" do
      params = %{
        startblock: 16000000,
        endblock: 16000100,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_internal_transactions_by_block_range(params) end)

      IO.puts("\n=== Internal Transactions By Block Range Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transactions}} = result
      # Could be an empty list or a list of transactions
      assert is_list(transactions)
    end

    test "raises error when startblock is missing" do
      assert_raise ArgumentError, "startblock parameter is required", fn ->
        AccountLens.get_internal_transactions_by_block_range(%{endblock: 16000100})
      end
    end

    test "raises error when endblock is missing" do
      assert_raise ArgumentError, "endblock parameter is required", fn ->
        AccountLens.get_internal_transactions_by_block_range(%{startblock: 16000000})
      end
    end
  end

  describe "get_erc20_token_transfers/1" do
    @tag :integration
    test "fetches ERC20 token transfers for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_erc20_token_transfers(params) end)

      IO.puts("\n=== ERC20 Token Transfers Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transfers}} = result
      # Could be an empty list or a list of transfers
      assert is_list(transfers)
    end

    @tag :integration
    test "fetches ERC20 token transfers for an address with contract filter" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        contractaddress: "0x6B175474E89094C44Da98b954EedeAC495271d0F", # DAI token
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_erc20_token_transfers(params) end)

      IO.puts("\n=== ERC20 Token Transfers with Contract Filter Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transfers}} = result
      # Could be an empty list or a list of transfers
      assert is_list(transfers)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_erc20_token_transfers(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_erc20_token_transfers(%{address: "invalid"})
      end
    end
  end

  describe "get_erc721_token_transfers/1" do
    @tag :integration
    test "fetches ERC721 token transfers for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_erc721_token_transfers(params) end)

      IO.puts("\n=== ERC721 Token Transfers Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transfers}} = result
      # Could be an empty list or a list of transfers
      assert is_list(transfers)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_erc721_token_transfers(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_erc721_token_transfers(%{address: "invalid"})
      end
    end
  end

  describe "get_erc1155_token_transfers/1" do
    @tag :integration
    test "fetches ERC1155 token transfers for an address with real API key" do
      params = %{
        address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
        startblock: 0,
        endblock: 99999999,
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_erc1155_token_transfers(params) end)

      IO.puts("\n=== ERC1155 Token Transfers Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: transfers}} = result
      # Could be an empty list or a list of transfers
      assert is_list(transfers)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_erc1155_token_transfers(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_erc1155_token_transfers(%{address: "invalid"})
      end
    end
  end

  describe "get_mined_blocks/1" do
    @tag :integration
    test "fetches mined blocks for an address with real API key" do
      params = %{
        address: "0xea674fdde714fd979de3edf0f56aa9716b898ec8", # Ethermine address
        blocktype: "blocks",
        page: 1,
        offset: 5 # Limit to 5 results for test
      }

      result = with_rate_limit(fn -> AccountLens.get_mined_blocks(params) end)

      IO.puts("\n=== Mined Blocks Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: blocks}} = result
      # Could be an empty list or a list of blocks
      assert is_list(blocks)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_mined_blocks(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_mined_blocks(%{address: "invalid"})
      end
    end
  end

  describe "get_beacon_withdrawals/1" do
    @tag :integration
    test "fetches beacon withdrawals for an address with real API key" do
      with_rate_limit(fn ->
        address = "0x7e2a2fa2a064f693f0a55c5639476d913ff12d05"
        result = AccountLens.get_beacon_withdrawals(%{address: address})
        IO.puts("\n=== Beacon Withdrawals Response ===")
        IO.puts("Result: #{inspect(result, pretty: true)}")

        # Check for either successful result or "No transactions found" message
        assert match?({:ok, %{result: _}}, result) or
               match?({:error, %{message: "No transactions found", result: []}}, result)
      end)
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        AccountLens.get_beacon_withdrawals(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        AccountLens.get_beacon_withdrawals(%{address: "invalid"})
      end
    end
  end
end
