defmodule Lux.YouTube.ContentCreation.ContentRepurposer do
  @moduledoc """
  Transforms long-form YouTube video concepts and scripts into multi-platform assets:
  Shorts / Reels / TikTok vertical scripts, Twitter/X viral threads, LinkedIn articles,
  and engineering blog summaries.
  """

  @type short_script :: %{
          hook: String.t(),
          body: String.t(),
          cta: String.t(),
          duration_seconds: non_neg_integer(),
          visual_prompt: String.t()
        }

  @type repurposed_package :: %{
          shorts_scripts: list(short_script()),
          twitter_thread: list(String.t()),
          linkedin_post: String.t(),
          blog_summary_markdown: String.t()
        }

  @doc """
  Repurposes a long-form video script or topic into multi-platform derivative content.
  """
  @spec repurpose(String.t(), map() | list(map())) :: repurposed_package()
  def repurpose(topic, script_data \\ %{}) do
    title =
      if is_map(script_data),
        do: Map.get(script_data, :title, Map.get(script_data, "title", topic)),
        else: topic

    shorts = generate_shorts(topic)
    thread = generate_twitter_thread(topic, title)
    linkedin = generate_linkedin_post(topic, title)
    blog = generate_blog_summary(topic, title)

    %{
      shorts_scripts: shorts,
      twitter_thread: thread,
      linkedin_post: linkedin,
      blog_summary_markdown: blog
    }
  end

  defp generate_shorts(topic) do
    [
      %{
        hook: "Most developers build #{topic} completely wrong. Here's why:",
        body: "Instead of monolithic scripts, modern architectures use autonomous supervised actors that isolate failures and scale concurrently.",
        cta: "Full step-by-step code tutorial linked on my channel profile!",
        duration_seconds: 45,
        visual_prompt: "Fast vertical cut: terminal crashing in red vs green automated recovery in green."
      },
      %{
        hook: "Here is the 1 trick that made my #{topic} 10x faster:",
        body: "By implementing asynchronous message passing instead of blocking synchronous HTTP polls, we reduced latency by 85%.",
        cta: "Follow for daily high-scale engineering tips!",
        duration_seconds: 35,
        visual_prompt: "Split-screen comparison showing flame graphs and latency drops."
      },
      %{
        hook: "Stop using outdated frameworks for #{topic} in 2026.",
        body: "The new paradigm uses declarative Agent Prisms with type-safe schema contracts. Here is how it works in 3 lines of code.",
        cta: "Watch the full breakdown on YouTube!",
        duration_seconds: 40,
        visual_prompt: "Clean IDE code snippet zooming in on Prism handler definition."
      }
    ]
  end

  defp generate_twitter_thread(topic, title) do
    [
      "🧵 1/7 Most teams struggle when scaling #{topic} in production.\n\nAfter architecting multi-agent systems handling millions of events, here are the 5 architectural principles we learned the hard way 👇",
      "2/7 Problem #1: Synchronous Bottlenecks.\n\nCalling third-party APIs synchronously inside worker loops will choke your throughput. Always decouple ingestion via asynchronous event mailboxes.",
      "3/7 Problem #2: Fragile Error Boundaries.\n\nNever allow an unhandled API exception to take down your coordinator. Build supervision trees that automatically restart failed worker processes in milliseconds.",
      "4/7 Problem #3: Missing Schema Contracts.\n\nUnvalidated LLM tool outputs corrupt downstream states. Enforce strict JSON schema contracts on both Prism inputs and outputs.",
      "5/7 Problem #4: Telemetry Blindness.\n\nTrack view velocity, latency distributions, and retry counts in real-time. If you cannot measure it, you cannot scale it.",
      "6/7 Summary Blueprint:\n- Decoupled event loops\n- Supervised fault tolerance\n- Strict schema enforcement\n- Continuous telemetry instrumentation",
      "7/7 We just dropped the complete code walkthrough and production blueprints on YouTube: '#{title}'.\n\nWatch full video & get the repo here: https://github.com/Spectral-Finance/lux\n\nRT if you found this valuable! 🔁"
    ]
  end

  defp generate_linkedin_post(topic, title) do
    """
    Building production-ready systems around #{topic} is no longer theoretical—it is an engineering imperative.

    In our latest technical deep dive, "#{title}", we explore the architectural shifts required to transition from fragile prototypes to resilient, enterprise-grade deployments.

    Key insights covered:
    ✅ Replacing blocking loops with resilient asynchronous supervision
    ✅ Type-safe input/output schemas for LLM agent prisms
    ✅ Automated telemetry and error-budget monitoring

    Watch the full technical walkthrough on our channel and inspect the open-source implementation.

    #SoftwareEngineering #DistributedSystems #AI #SystemArchitecture #TechLeadership
    """
    |> String.trim()
  end

  defp generate_blog_summary(topic, title) do
    """
    # Architecture Deep Dive: #{title}

    ## Executive Summary
    In modern software engineering, scaling #{topic} requires moving beyond naive scripting into structured, fault-tolerant actor architectures.

    ## Key Engineering Pillars
    1. **Supervised Resiliency**: Ensuring isolated agent failures do not propagate.
    2. **Strict Schema Contracts**: Preventing runtime state corruption with declarative prism schemas.
    3. **Automated Telemetry**: Ingesting real-time event analytics.

    ## Implementation Walkthrough
    Review our complete reference implementation and test suites in the open-source Lux repository:
    [Lux Framework on GitHub](https://github.com/Spectral-Finance/lux)
    """
    |> String.trim()
  end
end
