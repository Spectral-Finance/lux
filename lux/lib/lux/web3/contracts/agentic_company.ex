defmodule Lux.Web3.Contracts.AgenticCompany do
  @moduledoc """
  Agentic Company contract
  """
  use Ethers.Contract,
    abi_file: "priv/web3/abis/AgenticCompany.abi.json"
end
