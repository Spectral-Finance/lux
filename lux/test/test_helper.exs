ExUnit.start(exclude: [:skip, :integration, :unit, :external])

defmodule UnitAPICase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Lux.Integrations.Discord.Client, as: DiscordClient
  alias Lux.Integrations.Telegram.Client, as: TelegramClient
  alias Lux.Lenses.Etherscan
  alias Lux.LLM.Anthropic
  alias Lux.LLM.OpenAI
  alias Lux.LLM.TogetherAI

  using do
    quote do
      @moduletag :unit
    end
  end

  setup do
    Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
    Application.put_env(:lux, OpenAI, plug: {Req.Test, OpenAI})
    Application.put_env(:lux, Etherscan, plug: {Req.Test, Etherscan})
    Application.put_env(:lux, Anthropic, plug: {Req.Test, Anthropic})
    Application.put_env(:lux, DiscordClient, plug: {Req.Test, DiscordClientMock})
    Application.put_env(:lux, TelegramClient, plug: {Req.Test, TelegramClientMock})
    Application.put_env(:lux, TogetherAI, plug: {Req.Test, TogetherAI})
    :ok
  end
end

defmodule IntegrationCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

    end
  end
end
