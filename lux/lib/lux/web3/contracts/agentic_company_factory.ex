defmodule Lux.Web3.Contracts.AgenticCompanyFactory do
  @moduledoc """
  Agentic Company Factory contract
  """
  use Ethers.Contract,
    abi_file: "priv/web3/abis/AgenticCompanyFactory.abi.json",
    # Proxy
    default_address: "0xB42Fe8C5aE00C6Ae137EA8b31185b3fbe3540450"
end
