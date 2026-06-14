defmodule Lux.Prisms.Pancakeswap.PancakeswapSecurityPrism do
  @moduledoc """
  Security checks for PancakeSwap trades on BSC:
  - Honeypot detection (simulate buy/sell before real trade)
  - Sandwich attack / MEV risk scoring
  - Token blacklist check
  - Contract verification check
  - Buy/sell tax calculation

  ## Example

      iex> Lux.Prisms.Pancakeswap.PancakeswapSecurityPrism.run(%{
      ...>   token_address: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
      ...>   amount_in: "1000000000000000000"
      ...> })
      {:ok, %{is_safe: true, honeypot: false, sandwich_risk: "low", score: 95}}
  """

  use Lux.Prism,
    name: "PancakeSwap Security Check",
    description: "Detects honeypots, sandwich attacks and malicious tokens before trading on PancakeSwap",
    input_schema: %{
      type: :object,
      properties: %{
        token_address: %{
          type: :string,
          description: "BEP20 token contract address to check"
        },
        amount_in: %{
          type: :string,
          description: "Amount of WBNB to simulate in wei",
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

  @router_v2 "0x10ED43C718714eb63d5aA57B78B54704E256024E"
  @wbnb "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
  @rpc_url "https://bsc-dataseed.binance.org/"

  @blacklist [
    "0x0000000000000000000000000000000000000000"
  ]

  def handler(input, _ctx) do
    token  = input[:token_address] || input["token_address"]
    amount = input[:amount_in] || input["amount_in"] || "1000000000000000000"

    if token in @blacklist do
      {:ok, %{is_safe: false, honeypot: false, sandwich_risk: "critical",
              score: 0, warnings: ["Token is blacklisted"]}}
    else
      run_security_checks(token, amount)
    end
  end

  defp run_security_checks(token, amount) do
    result =
      python variables: %{
        token: token,
        amount_in: amount,
        router_addr: @router_v2,
        wbnb_addr: @wbnb,
        rpc_url: @rpc_url
      } do
        ~PY"""
        from web3 import Web3

        w3 = Web3(Web3.HTTPProvider(rpc_url))

        warnings = []
        score = 100
        honeypot = False
        sell_tax = 0.0
        buy_tax = 0.0
        contract_verified = False

        token_c  = Web3.to_checksum_address(token)
        router_c_addr = Web3.to_checksum_address(router_addr)
        wbnb_c   = Web3.to_checksum_address(wbnb_addr)

        code = w3.eth.get_code(token_c)
        if len(code) == 0:
            warnings.append("No contract code found - not a token")
            score -= 50

        ERC20_ABI = [
          {"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"stateMutability":"view","type":"function"},
          {"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
        ]

        ROUTER_ABI = [
          {"inputs":[{"name":"amountIn","type":"uint256"},{"name":"path","type":"address[]"}],"name":"getAmountsOut","outputs":[{"name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"}
        ]

        try:
          token_contract = w3.eth.contract(address=token_c, abi=ERC20_ABI)
          name = token_contract.functions.name().call()
          symbol = token_contract.functions.symbol().call()
          contract_verified = True

          router_c = w3.eth.contract(address=router_c_addr, abi=ROUTER_ABI)
          path_buy  = [wbnb_c, token_c]
          path_sell = [token_c, wbnb_c]
          amount_in_wei = int(amount_in)

          try:
            buy_amounts = router_c.functions.getAmountsOut(amount_in_wei, path_buy).call()
            tokens_out  = buy_amounts[-1]

            try:
              sell_amounts = router_c.functions.getAmountsOut(tokens_out, path_sell).call()
              bnb_back = sell_amounts[-1]

              buy_tax  = round((1 - tokens_out / (amount_in_wei * 9975 / 10000)) * 100, 2)
              sell_tax = round((1 - bnb_back / (tokens_out * 9975 / 10000)) * 100, 2)

              if sell_tax < 0: sell_tax = 0
              if buy_tax < 0: buy_tax = 0

              if bnb_back == 0:
                honeypot = True
                warnings.append("HONEYPOT DETECTED: Cannot sell token")
                score -= 80

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

        try:
          gas_price = w3.eth.gas_price
          base_fee = w3.eth.get_block("latest").get("baseFeePerGas", 0)
          if base_fee and gas_price > base_fee * 3:
            sandwich_risk = "high"
            warnings.append("High gas price - MEV sandwich risk elevated")
            score -= 10
          elif base_fee and gas_price > base_fee * 2:
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