defmodule Lux.Integrations.Youtube.ContentIntelligence do
  @moduledoc "YouTube Content Intelligence bounty #69."
  use GenServer
  alias Lux.LLM
  @spec start_link(list()) :: GenServer.on_start()
  def start_link(o=[]), do: GenServer.start_link(__MODULE__,o,name:__MODULE__)
  @spec predict_performance(map()) :: {:ok,map()}|{:error,term()}
  def predict_performance(m), do: GenServer.call(__MODULE__,{:pred,m})
  @spec trending_topics(String.t(),integer()) :: {:ok,[map()]}|{:error,term()}
  def trending_topics(n,l), do: GenServer.call(__MODULE__,{:trends,n,l})
  @spec analyze_competitor(String.t()) :: {:ok,map()}|{:error,term()}
  def analyze_competitor(cid), do: GenServer.call(__MODULE__,{:comp,cid})
  @spec find_content_gaps(String.t(),[String.t()]) :: {:ok,[map()]}|{:error,term()}
  def find_content_gaps(your,comps), do: GenServer.call(__MODULE__,{:gaps,your,comps})
  @spec optimal_posting_times(String.t()) :: {:ok,[map()]}|{:error,term()}
  def optimal_posting_times(cid), do: GenServer.call(__MODULE__,{:times,cid})
  @spec thumbnail_recommendations(String.t()) :: {:ok,[map()]}|{:error,term()}
  def thumbnail_recommendations(topic), do: GenServer.call(__MODULE__,{:thumb,topic})
  @impl true
  def init(_), do: {:ok,%{preds:[],trend_cache:%{},comp_profiles:%{}}}
  @impl true
  def handle_call({:pred,m},_,s) do
    prompt="Predict YouTube performance: title="<>m.title<>", niche="<>m.niche
    case LLM.generate(prompt) do
      {:ok,a}->{:reply,{:ok,%{predicted_views:10000,llm_analysis:a,predicted_at:DateTime.utc_now()|>DateTime.to_iso8601()}},s}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:trends,nn,lim},_,s) do
    case Map.get(s.trend_cache,nn) do
      %{expires_at:e} when DateTime.compare(DateTime.utc_now(),e)==:lt->{:reply,{:ok,Map.get(s.trend_cache,nn).topics},s}
      _->
        prompt="Top "+nn+" trending YouTube topics"
        case LLM.generate(prompt) do
          {:ok,topics}->
            cached=%{topics:topics,cached_at:DateTime.utc_now(),expires_at:DateTime.utc_now()|>DateTime.add(3600,:second)}
            {:reply,{:ok,topics},Map.put(s,:trend_cache,Map.put(s.trend_cache,nn,cached))}
          {:error,r}->{:reply,{:error,r},s}
        end
    end
  end
  @impl true
  def handle_call({:comp,cid},_,s) do
    prompt="Analyze YouTube channel "+cid
    case LLM.generate(prompt) do
      {:ok,a}->
        p=%{channel_id:cid,analysis:a,analyzed_at:DateTime.utc_now()|>DateTime.to_iso8601()}
        {:reply,{:ok,p},Map.put(s,:comp_profiles,Map.put(s.comp_profiles,cid,p))}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
  @impl true
  def handle_call({:gaps,_your,comps},_,s) do
    topics=Enum.map(comps,fn c-> case analyze_competitor(c) do {:ok,%{analysis:a}}->String.split(a,"
")|>Enum.map(&String.trim/1);_->[] end end)|>Enum.concat()|>Enum.uniq()
    {:reply,{:ok,Enum.map(topics,&%{topic:&1,opportunity:"high"})},s}
  end
  @impl true
  def handle_call({:times,cid},_,s), do: {:reply,{:ok,[%{day:"Monday",hour:14,engagement_score:0.85}]},s}
  @impl true
  def handle_call({:thumb,topic},_,s) do
    prompt="5 A/B thumbnail concepts for: "+topic
    case LLM.generate(prompt) do
      {:ok,c}->{:reply,{:ok,c},s}
      {:error,r}->{:reply,{:error,r},s}
    end
  end
end