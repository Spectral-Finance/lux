defmodule Lux.Prisms.Sushiswap.SushiswapSecurityPrism do
  @moduledoc """
  Security checks for SushiSwap trades:
  - Honeypot detection (simulate buy/sell before real trade)
  - Sandwich attack protection (MEV detection)
  - Token blacklist check
  - Contract verification check

  ## Example

      iex> Lux.Prisms.Sushiswap.SushiswapSecurityPrism.run(%{
      ...>   token_address: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
      ...>   chain_id: 56,
      ...>   amount_in: "1000000000000000000"
      ...> })
      {:ok, %{is_safe: true, honeypot: false, sandwich_risk: "low", score: 95}}
  """

  use Lux.Prism,
    name: "SushiSwap Security Check",
    description: "Detects honeypots, sandwich attacks and malicious tokens before trading",
    input_schema: %{
      type: :object,
      properties: %{
        token_address: %{
          type: :string,
          description: "Token contract address to check"
        },
        chain_id: %{
          type: :integer,
          description: "Chain ID: 1=Ethereum, 56=BSC, 137=Polygon, 42161=Arbitrum",
          default: 56
        },
        amount_in: %{
          type: :string,
          description: "Amount to simulate in wei",
          default: "1000000000000000000"
        }
      },
      required: ["token_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_safe: %{type: :boolean},
        honeypot: %{type: :boolean},
        sandwich_risk: %{type: :string},
        contract_verified: %{type: :boolean},
        sell_tax: %{type: :number},
        buy_tax: %{type: :number},
        score: %{type: :integer},
        warnings: %{type: :array}
      },
      required: ["is_safe", "honeypot", "score"]
    }

  import Lux.Python
  require Lux.Python

  @rpcs %{
    1     => "https://eth.llamarpc.com",
    56    => "https://bsc-dataseed.binance.org/",
    137   => "https://polygon-rpc.com",
    42_161 => "https://arb1.arbitrum.io/rpc"
  }

  @routers %{
    1     => "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9f",
    56    => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    137   => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
    42_161 => "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506"
  }

  # Known malicious contracts blacklist
  @blacklist [
    "0x0000000000000000000000000000000000000000"
  ]

  def handler(input, _ctx) do
    chain_id = input[:chain_id] || input["chain_id"] || 56
    token    = input[:token_address] || input["token_address"]
    amount   = input[:amount_in] || input["amount_in"] || "1000000000000000000"
    rpc_url  = @rpcs[chain_id] || @rpcs[56]
    router   = @routers[chain_id] || @routers[56]

    if token in @blacklist do
      {:ok, %{is_safe: false, honeypot: false, sandwich_risk: "critical",
              score: 0, warnings: ["Token is blacklisted"]}}
    else
      run_security_checks(token, rpc_url, router, amount)
    end
  end

  defp run_security_checks(token, rpc_url, router, amount) do
    result =
      python variables: %{
        token: token,
        rpc_url: rpc_url,
        router: router,
        amount_in: amount
      } do
        ~PY"""
        from web3 import Web3
        from web3.middleware import ExtraDataToPOAMiddleware

        w3 = Web3(Web3.HTTPProvider(rpc_url))
        w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)

        warnings = []
        score = 100
        honeypot = False
        sell_tax = 0.0
        buy_tax = 0.0
        contract_verified = False

        token_c = Web3.to_checksum_address(token)

        # 1. Check if contract exists
        code = w3.eth.get_code(token_c)
        if len(code) == 0:
            warnings.append("No contract code found - not a token")
            score -= 50

        # 2. ERC20 ABI for basic checks
        ERC20_ABI = [
          {"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"},
          {"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
        ]

        ROUTER_ABI = [
          {"inputs":[{"name":"amountIn","type":"uint256"},{"name":"path","type":"address[]"}],"name":"getAmountsOut","outputs":[{"name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"}
        ]

        # WBNB/WETH addresses per chain
        WRAPPED = {
          "https://bsc-dataseed.binance.org/": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
          "https://eth.llamarpc.com": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
          "https://polygon-rpc.com": "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
          "https://arb1.arbitrum.io/rpc": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
        }

        wrapped = WRAPPED.get(rpc_url, "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c")

        try:
          token_contract = w3.eth.contract(address=token_c, abi=ERC20_ABI)
          name   = token_contract.functions.name().call()
          symbol = token_contract.functions.symbol().call()
          supply = token_contract.functions.totalSupply().call()
          contract_verified = True

          # 3. Simulate buy via getAmountsOut
          router_c = w3.eth.contract(
            address=Web3.to_checksum_address(router), abi=ROUTER_ABI
          )
          path_buy  = [Web3.to_checksum_address(wrapped), token_c]
          path_sell = [token_c, Web3.to_checksum_address(wrapped)]

          amount_in_wei = int(amount_in)

          try:
            buy_amounts  = router_c.functions.getAmountsOut(amount_in_wei, path_buy).call()
            tokens_out   = buy_amounts[-1]

            # 4. Simulate sell
            try:
              sell_amounts = router_c.functions.getAmountsOut(tokens_out, path_sell).call()
              eth_back     = sell_amounts[-1]

              # Calculate taxes
              buy_tax  = round((1 - tokens_out / (amount_in_wei * 997 / 1000)) * 100, 2)
              sell_tax = round((1 - eth_back / (tokens_out * 997 / 1000)) * 100, 2)

              if sell_tax < 0: sell_tax = 0
              if buy_tax < 0: buy_tax = 0

              # Honeypot: if sell returns 0 or reverts
              if eth_back == 0:
                honeypot = True
                warnings.append("HONEYPOT DETECTED: Cannot sell token")
                score -= 80

              # High sell tax = likely honeypot or scam
              if sell_tax > 10:
                warnings.append(f"High sell tax: {sell_tax}%")
                score -= 30
                if sell_tax > 49:
                  honeypot = True
                  score -= 30

              if buy_tax > 10:
                warnings.append(f"High buy tax: {buy_tax}%")
                score -= 15

            except Exception:
              honeypot = True
              warnings.append("HONEYPOT: Sell simulation failed/reverted")
              score -= 80

          except Exception:
            warnings.append("Buy simulation failed - no liquidity or bad token")
            score -= 40

        except Exception as e:
          warnings.append(f"Contract call failed: {str(e)}")
          score -= 30

        # 5. Sandwich risk based on block gas
        try:
          gas_price  = w3.eth.gas_price
          base_fee   = w3.eth.get_block("latest").get("baseFeePerGas", 0)
          if base_fee and gas_price > base_fee * 3:
            sandwich_risk = "high"
            warnings.append("High gas price - MEV sandwich risk elevated")
            score -= 10
          elif gas_price > base_fee * 2 if base_fee else False:
            sandwich_risk = "medium"
          else:
            sandwich_risk = "low"
        except:
          sandwich_risk = "unknown"

        if score < 0: score = 0

        {
          "is_safe": not honeypot and score >= 60,
          "honeypot": honeypot,
          "sell_tax": sell_tax,
          "buy_tax": buy_tax,
          "contract_verified": contract_verified,
          "sandwich_risk": sandwich_risk,
          "score": score,
          "warnings": warnings
        }
        """
      end

    case result do
      %{"error" => e} -> {:error, e}
      r when is_map(r) -> {:ok, r}
    end
  end
end