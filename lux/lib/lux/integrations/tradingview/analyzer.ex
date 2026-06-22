defmodule Lux.Integrations.TradingView.Analyzer do
  @moduledoc "TradingView Technical Analysis ($600 bounty #86)."
  @spec sma([number()], integer()) :: [number()]
  def sma(data, p) when length(data) >= p, do: data |> Enum.chunk_every(p, 1, :discard) |> Enum.map(&(Enum.sum(&1)/length(&1)))
  def sma(_d, _p), do: []
  @spec ema([number()], integer()) :: number()
  def ema(d, p) do m = 2/(p+1); case d do [f|r] -> cema(r,f,m,p); [] -> 0.0 end end
  defp cema([],p,_,_), do: p
  defp cema([c|r],prev,m,pt), do: cema(r,(c-prev)*m+prev,m,pt)
  @spec rsi([number()], integer()) :: number()
  def rsi(d, p  14) when length(d) > p do
    ch = Enum.zip(d, Enum.drop(d,1)) |> Enum.map(fn {a,b} -> b-a end)
    ag = ch |> Enum.filter(&(&1>0)) |> Enum.map(&abs/1) |> then(&if Enum.empty?(&1), do: 0, else: Enum.sum(&1)/p)
    al = ch |> Enum.filter(&(&1<0)) |> Enum.map(&abs/1) |> then(&if Enum.empty?(&1), do: 0, else: Enum.sum(&1)/p)
    if al == 0, do: 100, else: 100 - (100/(1+ag/al))
  end
  def rsi(_d, _p), do: 50.0
  @spec macd([number()]) :: %{fast: number(), slow: number(), signal: number(), histogram: number()}
  def macd(d), do: %{fast: ema(d,12), slow: ema(d,26), signal: 0, histogram: 0}
  @spec bollinger_bands([number()], integer(), number()) :: %{upper: number(), middle: number(), lower: number()}
  def bollinger_bands(d, p  20, sm  2) do
    s = sma(d,p) |> List.last()
    w = d |> Enum.take(-p)
    v = Enum.sum(Enum.map(w, &( &1-s)**2))/p
    sd = :math.sqrt(v)
    %{upper: s+sm*sd, middle: s, lower: s-sm*sd}
  end
  @spec generate_signal([number()]) :: %{signal: atom(), score: number(), indicators: map()}
  def generate_signal(pd) when length(pd) > 30 do
    r = rsi(pd); m = macd(pd); b = bollinger_bands(pd); last = List.last(pd)
    rs = if r<30, do: 1.0, else: if(r>70, do: -1.0, else: 0.0)
    ms = if m.histogram>0, do: 1.0, else: -1.0
    rng = b.upper-b.lower; bs = if rng==0, do: 0, else: 1-2*(last-b.lower)/rng
    tot = (rs+ms+bs)/3
    sig = cond do tot>0.5 -> :strong_buy; tot>0.1 -> :buy; tot<-0.5 -> :strong_sell; tot<-0.1 -> :sell; true -> :hold end
    %{signal: sig, score: Float.round(tot,3), indicators: %{rsi: Float.round(r,2), macd_histogram: Float.round(m.histogram,6), price: last}}
  end
  def generate_signal(_d), do: %{signal: :hold, score: 0.0, indicators: %{}}
end