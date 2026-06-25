defmodule Lux.Web3.Wallet.Backup do
  @moduledoc "Wallet backup and restore."
  @spec export_wallet(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def export_wallet(addr, "encrypted_json"), do: {:ok, %{format:"lux_wallet_backup",version:"1.0",address:addr,exported_at:DateTime.utc_now()|>DateTime.to_iso8601(),encrypted:true}}
  def export_wallet(_,f), do: {:error, "Unsupported: #{f}"}
  @spec import_wallet(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def import_wallet(%{format:"lux_wallet_backup",address:a},_), do: {:ok, %{address:a,restored:true}}
  def import_wallet(_,_), do: {:error, "Invalid backup"}
end