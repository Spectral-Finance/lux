defmodule Lux.Prisms.YouTube.ScriptGenerator do
  @moduledoc """
  Video script generation system with templates, outlines, and multi-language support.
  """

  use GenServer

  defstruct [:templates, :scripts, :languages]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def generate(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:generate, params})
  end

  def add_template(pid \\ __MODULE__, template) do
    GenServer.call(pid, {:add_template, template})
  end

  def list_templates(pid \\ __MODULE__) do
    GenServer.call(pid, :list_templates)
  end

  def get_script(pid \\ __MODULE__, script_id) do
    GenServer.call(pid, {:get_script, script_id})
  end

  def translate(pid \\ __MODULE__, script_id, target_lang) do
    GenServer.call(pid, {:translate, script_id, target_lang})
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{
      templates: default_templates(),
      scripts: %{},
      languages: ["en", "es", "fr", "de", "ja", "zh", "ko", "pt"]
    }}
  end

  @impl true
  def handle_call({:generate, params}, _from, state) do
    template = find_template(state.templates, params[:template] || :tutorial)
    id = gen_id()

    sections = Enum.map(template.sections, fn section ->
      %{
        name: section.name,
        duration_seconds: section.duration_seconds,
        content: interpolate(section.content_template, params),
        notes: section.notes
      }
    end)

    script = %{
      id: id,
      title: params[:title] || "Untitled",
      topic: params[:topic],
      template: template.name,
      sections: sections,
      total_duration: Enum.sum(Enum.map(sections, & &1.duration_seconds)),
      language: params[:language] || "en",
      tags: generate_tags(params[:topic]),
      created_at: DateTime.utc_now()
    }

    {:reply, {:ok, script}, %{state | scripts: Map.put(state.scripts, id, script)}}
  end

  @impl true
  def handle_call({:add_template, template}, _from, state) do
    id = template[:id] || gen_id()
    entry = %{
      id: id,
      name: template[:name],
      sections: template[:sections] || [],
      category: template[:category] || :general
    }
    {:reply, {:ok, entry}, %{state | templates: [entry | state.templates]}}
  end

  @impl true
  def handle_call(:list_templates, _from, state) do
    {:reply, {:ok, state.templates}, state}
  end

  @impl true
  def handle_call({:get_script, script_id}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil -> {:reply, {:error, :not_found}, state}
      script -> {:reply, {:ok, script}, state}
    end
  end

  @impl true
  def handle_call({:translate, script_id, target_lang}, _from, state) do
    case Map.get(state.scripts, script_id) do
      nil -> {:reply, {:error, :not_found}, state}
      script ->
        translated = %{script |
          id: gen_id(),
          language: target_lang,
          title: "[#{target_lang}] #{script.title}",
          sections: Enum.map(script.sections, fn s ->
            %{s | content: "[#{target_lang}] #{s.content}"}
          end)
        }
        {:reply, {:ok, translated},
         %{state | scripts: Map.put(state.scripts, translated.id, translated)}}
    end
  end

  defp default_templates do
    [
      %{
        id: "tutorial", name: :tutorial, category: :educational,
        sections: [
          %{name: "Hook", duration_seconds: 15, content_template: "In this video, we'll learn about {{topic}}.", notes: "Grab attention"},
          %{name: "Introduction", duration_seconds: 30, content_template: "Welcome! Today's topic is {{topic}}.", notes: "Set expectations"},
          %{name: "Main Content", duration_seconds: 300, content_template: "Let's dive into {{topic}} step by step.", notes: "Core teaching"},
          %{name: "Summary", duration_seconds: 30, content_template: "To recap what we learned about {{topic}}.", notes: "Key takeaways"},
          %{name: "CTA", duration_seconds: 15, content_template: "Subscribe for more on {{topic}}!", notes: "Call to action"}
        ]
      },
      %{
        id: "review", name: :review, category: :entertainment,
        sections: [
          %{name: "Hook", duration_seconds: 10, content_template: "Is {{topic}} worth it?", notes: "Tease verdict"},
          %{name: "Overview", duration_seconds: 60, content_template: "Let me tell you about {{topic}}.", notes: "Background"},
          %{name: "Pros", duration_seconds: 120, content_template: "The best things about {{topic}}.", notes: "Positives"},
          %{name: "Cons", duration_seconds: 120, content_template: "The downsides of {{topic}}.", notes: "Negatives"},
          %{name: "Verdict", duration_seconds: 60, content_template: "My final thoughts on {{topic}}.", notes: "Recommendation"}
        ]
      }
    ]
  end

  defp find_template(templates, name) do
    Enum.find(templates, hd(templates), &(&1.name == name))
  end

  defp interpolate(text, params) do
    text
    |> String.replace("{{topic}}", params[:topic] || "")
    |> String.replace("{{title}}", params[:title] || "")
  end

  defp generate_tags(nil), do: []
  defp generate_tags(topic) do
    topic
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.take(10)
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
