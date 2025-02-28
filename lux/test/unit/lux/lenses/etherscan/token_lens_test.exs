defmodule Lux.Lenses.Etherscan.TokenLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.TokenLens

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

  describe "get_token_supply/1" do
    @tag :integration
    test "fetches token supply for a valid contract address" do
      # Using USDT token address as an example
      contract_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"

      result = with_rate_limit(fn ->
        TokenLens.get_token_supply(%{
          contractaddress: contract_address
        })
      end)

      IO.puts("\n=== Token Supply Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: supply}} = result
      assert is_binary(supply)
      # USDT has 6 decimals, so supply should be a large number
      {supply_int, _} = Integer.parse(supply)
      assert supply_int > 0
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_token_supply(%{})
      end
    end

    test "raises error when contract address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        TokenLens.get_token_supply(%{contractaddress: "invalid"})
      end
    end
  end

  describe "get_token_balance/1" do
    @tag :integration
    test "fetches token balance for a valid address and contract" do
      # Using USDT token address and a known holder
      contract_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"
      address = "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A" # Random USDT holder

      result = with_rate_limit(fn ->
        TokenLens.get_token_balance(%{
          contractaddress: contract_address,
          address: address
        })
      end)

      IO.puts("\n=== Token Balance Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: balance}} = result
      assert is_binary(balance)
      # Balance should be parseable as an integer
      {balance_int, _} = Integer.parse(balance)
      assert is_integer(balance_int)
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_token_balance(%{
          address: "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A"
        })
      end
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        TokenLens.get_token_balance(%{
          contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7"
        })
      end
    end

    test "raises error when contract address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        TokenLens.get_token_balance(%{
          contractaddress: "invalid",
          address: "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A"
        })
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        TokenLens.get_token_balance(%{
          contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
          address: "invalid"
        })
      end
    end
  end

  describe "get_historical_token_supply/1" do
    @tag :integration
    test "handles historical token supply request" do
      # Using USDT token address as an example
      contract_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"
      block_number = 9000000

      result = with_rate_limit(fn ->
        TokenLens.get_historical_token_supply(%{
          contractaddress: contract_address,
          blockno: block_number
        })
      end)

      IO.puts("\n=== Historical Token Supply Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: supply}} ->
          assert is_binary(supply)
          {supply_int, _} = Integer.parse(supply)
          assert supply_int > 0
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_historical_token_supply(%{
          blockno: 9000000
        })
      end
    end

    test "raises error when block number is missing" do
      assert_raise ArgumentError, "blockno parameter is required", fn ->
        TokenLens.get_historical_token_supply(%{
          contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7"
        })
      end
    end
  end

  describe "get_historical_token_balance/1" do
    @tag :integration
    test "handles historical token balance request" do
      # Using USDT token address and a known holder
      contract_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"
      address = "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A" # Random USDT holder
      block_number = 9000000

      result = with_rate_limit(fn ->
        TokenLens.get_historical_token_balance(%{
          contractaddress: contract_address,
          address: address,
          blockno: block_number
        })
      end)

      IO.puts("\n=== Historical Token Balance Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: balance}} ->
          assert is_binary(balance)
          {balance_int, _} = Integer.parse(balance)
          assert is_integer(balance_int)
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_historical_token_balance(%{
          address: "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A",
          blockno: 9000000
        })
      end

      assert_raise ArgumentError, "address parameter is required", fn ->
        TokenLens.get_historical_token_balance(%{
          contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
          blockno: 9000000
        })
      end

      assert_raise ArgumentError, "blockno parameter is required", fn ->
        TokenLens.get_historical_token_balance(%{
          contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
          address: "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A"
        })
      end
    end
  end

  describe "get_token_holder_list/1" do
    @tag :integration
    test "handles token holder list request" do
      # Using a token address as an example
      contract_address = "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"

      result = with_rate_limit(fn ->
        TokenLens.get_token_holder_list(%{
          contractaddress: contract_address,
          page: 1,
          offset: 10
        })
      end)

      IO.puts("\n=== Token Holder List Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: holders}} ->
          assert is_list(holders)
          if length(holders) > 0 do
            first_holder = List.first(holders)
            assert is_map(first_holder)
            assert Map.has_key?(first_holder, "TokenHolderAddress")
            assert Map.has_key?(first_holder, "TokenHolderQuantity")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_token_holder_list(%{})
      end
    end
  end

  describe "get_token_holder_count/1" do
    @tag :integration
    test "handles token holder count request" do
      # Using a token address as an example
      contract_address = "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"

      result = with_rate_limit(fn ->
        TokenLens.get_token_holder_count(%{
          contractaddress: contract_address
        })
      end)

      IO.puts("\n=== Token Holder Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: count}} ->
          assert is_binary(count)
          {count_int, _} = Integer.parse(count)
          assert count_int > 0
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_token_holder_count(%{})
      end
    end
  end

  describe "get_token_info/1" do
    @tag :integration
    test "fetches token info for a valid contract address" do
      # Using a token address as an example
      contract_address = "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"

      result = with_rate_limit(fn ->
        TokenLens.get_token_info(%{
          contractaddress: contract_address
        })
      end)

      IO.puts("\n=== Token Info Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: token_info}} ->
          assert is_list(token_info)

          if length(token_info) > 0 do
            first_info = List.first(token_info)
            assert is_map(first_info)
            # Check for some common token info fields
            assert Map.has_key?(first_info, "contractAddress")
            assert Map.has_key?(first_info, "tokenName")
            assert Map.has_key?(first_info, "symbol")
            assert Map.has_key?(first_info, "divisor")
            assert Map.has_key?(first_info, "tokenType")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when contract address is missing" do
      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_token_info(%{})
      end
    end
  end

  describe "get_address_erc20_token_holdings/1" do
    @tag :integration
    test "fetches ERC20 token holdings for a valid address" do
      # Using a known address with token holdings
      address = "0x983e3660c0bE01991785F80f266A84B911ab59b0"

      result = with_rate_limit(fn ->
        TokenLens.get_address_erc20_token_holdings(%{
          address: address,
          page: 1,
          offset: 10
        })
      end)

      IO.puts("\n=== Address ERC20 Token Holdings Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: holdings}} ->
          assert is_list(holdings)

          if length(holdings) > 0 do
            first_holding = List.first(holdings)
            assert is_map(first_holding)
            # Check for common token holding fields
            assert Map.has_key?(first_holding, "TokenAddress")
            assert Map.has_key?(first_holding, "TokenName")
            assert Map.has_key?(first_holding, "TokenSymbol")
            assert Map.has_key?(first_holding, "TokenQuantity")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        TokenLens.get_address_erc20_token_holdings(%{})
      end
    end
  end

  describe "get_address_erc721_token_holdings/1" do
    @tag :integration
    test "fetches ERC721 token holdings for a valid address" do
      # Using a known address with NFT holdings
      address = "0x6b52e83941eb10f9c613c395a834457559a80114"

      result = with_rate_limit(fn ->
        TokenLens.get_address_erc721_token_holdings(%{
          address: address,
          page: 1,
          offset: 10
        })
      end)

      IO.puts("\n=== Address ERC721 Token Holdings Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: holdings}} ->
          assert is_list(holdings)

          if length(holdings) > 0 do
            first_holding = List.first(holdings)
            assert is_map(first_holding)
            # Check for common NFT holding fields
            assert Map.has_key?(first_holding, "TokenAddress")
            assert Map.has_key?(first_holding, "TokenName")
            assert Map.has_key?(first_holding, "TokenSymbol")
            assert Map.has_key?(first_holding, "TokenQuantity")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        TokenLens.get_address_erc721_token_holdings(%{})
      end
    end
  end

  describe "get_address_erc721_token_inventory/1" do
    @tag :integration
    test "fetches ERC721 token inventory for a valid address and contract" do
      # Using a known address with NFT holdings and a specific NFT contract
      address = "0x123432244443b54409430979df8333f9308a6040"
      contract_address = "0xed5af388653567af2f388e6224dc7c4b3241c544" # Azuki

      result = with_rate_limit(fn ->
        TokenLens.get_address_erc721_token_inventory(%{
          address: address,
          contractaddress: contract_address,
          page: 1,
          offset: 10
        })
      end)

      IO.puts("\n=== Address ERC721 Token Inventory Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: inventory}} ->
          assert is_list(inventory)

          if length(inventory) > 0 do
            first_item = List.first(inventory)
            assert is_map(first_item)
            # Check for common NFT inventory fields
            assert Map.has_key?(first_item, "tokenAddress")
            assert Map.has_key?(first_item, "tokenId")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        TokenLens.get_address_erc721_token_inventory(%{
          contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544"
        })
      end

      assert_raise ArgumentError, "contractaddress parameter is required", fn ->
        TokenLens.get_address_erc721_token_inventory(%{
          address: "0x123432244443b54409430979df8333f9308a6040"
        })
      end
    end
  end
end
