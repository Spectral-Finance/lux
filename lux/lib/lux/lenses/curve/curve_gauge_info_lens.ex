defmodule Lux.Lenses.Curve.CurveGaugeInfoLens do
  @moduledoc """
  A lens for fetching Curve Finance gauge information and reward rates.

  Returns gauge TVL, current CRV emission rate, boost multiplier info,
  and working supply. Useful for comparing gauges to maximise yield.

  ## Example

      iex> Lux.Lenses.Curve.CurveGaugeInfoLens.focus(%{
      ...>   gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
      ...> }, %{agent: %{name: "YieldAgent"}})
      {:ok, %{
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        total_staked: "85000000000000000000000000",
        working_supply: "40000000000000000000000000",
        crv_rate: "1234567890123456",
        inflation_rate: "2400000000000000",
        relative_weight: 0.045,
        boost_max: 2.5,
        crv_apy_estimate: 3.2
      }}
  """

  use Lux.Lens,
    name: "Curve Gauge Info",
    description: "Fetches Curve gauge metrics: staked TVL, CRV emission rate, boost info, and APY estimate",
    schema: %{
      type: :object,
      properties: %{
        gauge_address: %{
          type: :string,
          description: "Curve gauge contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["gauge_address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @gauge_controller_address "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"
  @crv_minter_address "0xd061D61a4d941c39E5453435B6345Dc261C2fcE0"

  @impl true
  def focus(%{gauge_address: gauge_address}, agent) do
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"
    Logger.info("Agent #{agent_name} fetching gauge info for #{gauge_address}")

    rpc_url = get_rpc_url()

    with {:ok, result} <- fetch_gauge_info(rpc_url, gauge_address, @gauge_controller_address, @crv_minter_address) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_rpc_url do
    case Config.get(:curve_rpc_url) do
      nil -> System.get_env("CURVE_RPC_URL") || "https://eth.llamarpc.com"
      url -> url
    end
  rescue
    _ -> System.get_env("CURVE_RPC_URL") || "https://eth.llamarpc.com"
  end

  defp fetch_gauge_info(rpc_url, gauge_address, gauge_controller, crv_minter) do
    result =
      python variables: %{
               rpc_url: rpc_url,
               gauge_address: gauge_address,
               gauge_controller_address: gauge_controller,
               crv_minter_address: crv_minter
             } do
        ~PY"""
        from web3 import Web3

        GAUGE_ABI = [
            {"name": "totalSupply", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "working_supply", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "inflation_rate", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "uint256"}]},
            {"name": "lp_token", "type": "function", "inputs": [],
             "outputs": [{"name": "", "type": "address"}]}
        ]

        CONTROLLER_ABI = [
            {"name": "gauge_relative_weight", "type": "function",
             "inputs": [{"name": "addr", "type": "address"}, {"name": "time", "type": "uint256"}],
             "outputs": [{"name": "", "type": "uint256"}]}
        ]

        try:
            w3 = Web3(Web3.HTTPProvider(rpc_url))
            gauge_addr = Web3.to_checksum_address(gauge_address)
            gauge = w3.eth.contract(address=gauge_addr, abi=GAUGE_ABI)
            controller = w3.eth.contract(
                address=Web3.to_checksum_address(gauge_controller_address),
                abi=CONTROLLER_ABI
            )

            total_staked = gauge.functions.totalSupply().call()

            working_supply = 0
            try:
                working_supply = gauge.functions.working_supply().call()
            except Exception:
                working_supply = total_staked

            inflation_rate = 0
            try:
                inflation_rate = gauge.functions.inflation_rate().call()
            except Exception:
                pass

            # Get relative weight from gauge controller
            current_time = w3.eth.get_block("latest")["timestamp"]
            relative_weight = 0
            try:
                rw = controller.functions.gauge_relative_weight(gauge_addr, current_time).call()
                relative_weight = rw / 10**18
            except Exception:
                pass

            # CRV rate = inflation_rate * relative_weight / working_supply
            crv_rate = 0
            if working_supply > 0 and inflation_rate > 0:
                crv_rate = int(inflation_rate * relative_weight * 10**18 / working_supply)

            # Estimate APY: crv_rate per second * 365 days in % (rough, no CRV price)
            # Real APY needs CRV price & LP token price — emit rate for agents to compute
            crv_annual_per_lp = (crv_rate / 10**18) * 86400 * 365 if working_supply > 0 else 0

            {
                "gauge_address": gauge_address,
                "total_staked": str(total_staked),
                "working_supply": str(working_supply),
                "crv_rate": str(crv_rate),
                "inflation_rate": str(inflation_rate),
                "relative_weight": round(relative_weight, 6),
                "boost_max": 2.5,
                "crv_annual_per_lp": round(crv_annual_per_lp, 8)
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      {:ok, %{
        gauge_address: result["gauge_address"],
        total_staked: result["total_staked"],
        working_supply: result["working_supply"],
        crv_rate: result["crv_rate"],
        inflation_rate: result["inflation_rate"],
        relative_weight: result["relative_weight"],
        boost_max: result["boost_max"],
        crv_annual_per_lp: result["crv_annual_per_lp"]
      }}
    end
  end
end
