defmodule Lux.Rust.TypeSystem do
  @moduledoc "Rust Type System bounty #101."
  @typedoc :: capability :: :trading|:analytics|:communication|:monitoring|:content
  @typedoc :: risk_level :: :low|:medium|:high
  @type position :: %{symbol:String.t(),side::long|:short,size:float(),entry_price:float(),stop_loss:float()|nil,take_profit:float()|nil}
  @spec define_capability(String.t(),[String.t()]) :: map()
  def define_capability(name,skills), do: %{type::capability,name:name,skills:skills,constraints:%{},version:"1.0"}
  @spec create_position(String.t(),:long|:short,float(),float()) :: {:ok,position()}|{:error,String.t()}
  def create_position(sym,side,size,ep) do
    cond do size<=0->{:error,"size>0"}; ep<=0->{:error,"price>0"}; String.length(sym)<3->{:error,"bad sym"}; true->{:ok,%{symbol:String.upcase(sym),side:side,size:size,entry_price:ep,stop_loss:nil,take_profit:nil}} end
  end
  @spec validate_risk(position(),risk_level()) :: {:ok,risk_level()}|{:error,String.t()}
  def validate_risk(p,:low) when p.size*p.entry_price>100000, do:{:error,"too large"}
  def validate_risk(_,l), do:{:ok,l}
  @spec to_rust_type(map()) :: String.t()
  def to_rust_type(schema) do
    fields=Enum.map_join(schema.fields||[],",
    ",fn{n,t} -> n+": "+rt(t) end)
    "pub struct "+schema.name+" {
    "+fields+"
}"
  end
  defp rt(:string),do:"String"; defp rt(:integer),do:"i64"; defp rt(:float),do:"f64"; defp rt(:bool),do:"bool"; defp rt(_),do:"Value"
end