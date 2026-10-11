/**
 * LLM Provider Abstraction Layer
 * ---------------------------------
 * Resolves Spectral-Finance/lux issue #99 ($600 bounty).
 *
 * A single, provider-agnostic interface (`LLMProvider`) that all model
 * backends implement, plus a `ProviderRegistry` that resolves providers by
 * name, supports priority-ordered fallback, retries transient failures with
 * exponential backoff, and normalizes request/response shapes across
 * OpenAI, Anthropic, and local Ollama models.
 */

export type Role = "system" | "user" | "assistant";

export interface ChatMessage {
  role: Role;
  content: string;
}

export interface CompletionRequest {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  maxTokens?: number;
  stream?: boolean;
  /** Arbitrary provider-specific passthrough options. */
  extra?: Record<string, unknown>;
}

export interface TokenUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface CompletionResponse {
  /** The provider that actually served the request. */
  provider: string;
  model: string;
  content: string;
  finishReason: "stop" | "length" | "content_filter" | "error" | "unknown";
  usage: TokenUsage;
  /** Raw provider payload, preserved for advanced callers. */
  raw?: unknown;
}

export interface ProviderConfig {
  apiKey?: string;
  baseUrl?: string;
  /** Default model when the request omits one. */
  defaultModel?: string;
  timeoutMs?: number;
  maxRetries?: number;
}

/**
 * Every backend implements this. `name` must be unique within a registry.
 */
export interface LLMProvider {
  readonly name: string;
  readonly defaultModel: string;
  complete(req: CompletionRequest): Promise<CompletionResponse>;
  /** Optional streaming; providers that cannot stream may omit this. */
  stream?(req: CompletionRequest): AsyncIterable<string>;
  /** Cheap liveness probe used by the registry's health checks. */
  healthCheck?(): Promise<boolean>;
}

export class ProviderError extends Error {
  constructor(
    message: string,
    readonly provider: string,
    readonly status?: number,
    readonly retryable: boolean = false,
  ) {
    super(message);
    this.name = "ProviderError";
  }
}

const RETRYABLE_STATUS = new Set([408, 409, 425, 429, 500, 502, 503, 504]);

function isRetryable(err: unknown): boolean {
  if (err instanceof ProviderError) return err.retryable;
  // Network-level failures (fetch throws TypeError) are worth retrying.
  return err instanceof TypeError;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Exponential backoff with full jitter. */
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number,
  provider: string,
): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (attempt === maxRetries || !isRetryable(err)) break;
      const backoff = Math.min(2 ** attempt * 250, 8000);
      const jitter = Math.random() * backoff * 0.5;
      await sleep(backoff + jitter);
    }
  }
  throw lastErr instanceof Error
    ? lastErr
    : new ProviderError(String(lastErr), provider);
}

async function postJson(
  url: string,
  headers: Record<string, string>,
  body: unknown,
  timeoutMs: number,
  provider: string,
): Promise<any> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "content-type": "application/json", ...headers },
      body: JSON.stringify(body),
      signal: ctrl.signal,
    });
    const text = await res.text();
    if (!res.ok) {
      throw new ProviderError(
        `${provider} HTTP ${res.status}: ${text.slice(0, 500)}`,
        provider,
        res.status,
        RETRYABLE_STATUS.has(res.status),
      );
    }
    return text ? JSON.parse(text) : {};
  } finally {
    clearTimeout(timer);
  }
}

/* ------------------------------- OpenAI -------------------------------- */

export class OpenAIProvider implements LLMProvider {
  readonly name = "openai";
  readonly defaultModel: string;
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly timeoutMs: number;
  private readonly maxRetries: number;

  constructor(cfg: ProviderConfig = {}) {
    this.apiKey = cfg.apiKey ?? process.env.OPENAI_API_KEY ?? "";
    this.baseUrl = cfg.baseUrl ?? "https://api.openai.com/v1";
    this.defaultModel = cfg.defaultModel ?? "gpt-4o-mini";
    this.timeoutMs = cfg.timeoutMs ?? 60_000;
    this.maxRetries = cfg.maxRetries ?? 2;
  }

  async complete(req: CompletionRequest): Promise<CompletionResponse> {
    const model = req.model || this.defaultModel;
    const data = await withRetry(
      () =>
        postJson(
          `${this.baseUrl}/chat/completions`,
          { authorization: `Bearer ${this.apiKey}` },
          {
            model,
            messages: req.messages,
            temperature: req.temperature,
            max_tokens: req.maxTokens,
            ...req.extra,
          },
          this.timeoutMs,
          this.name,
        ),
      this.maxRetries,
      this.name,
    );
    const choice = data.choices?.[0] ?? {};
    const usage = data.usage ?? {};
    return {
      provider: this.name,
      model: data.model ?? model,
      content: choice.message?.content ?? "",
      finishReason: normalizeFinish(choice.finish_reason),
      usage: {
        promptTokens: usage.prompt_tokens ?? 0,
        completionTokens: usage.completion_tokens ?? 0,
        totalTokens: usage.total_tokens ?? 0,
      },
      raw: data,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/models`, {
        headers: { authorization: `Bearer ${this.apiKey}` },
      });
      return res.ok;
    } catch {
      return false;
    }
  }
}

/* ------------------------------ Anthropic ------------------------------ */

export class AnthropicProvider implements LLMProvider {
  readonly name = "anthropic";
  readonly defaultModel: string;
  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly timeoutMs: number;
  private readonly maxRetries: number;

  constructor(cfg: ProviderConfig = {}) {
    this.apiKey = cfg.apiKey ?? process.env.ANTHROPIC_API_KEY ?? "";
    this.baseUrl = cfg.baseUrl ?? "https://api.anthropic.com/v1";
    this.defaultModel = cfg.defaultModel ?? "claude-3-5-sonnet-latest";
    this.timeoutMs = cfg.timeoutMs ?? 60_000;
    this.maxRetries = cfg.maxRetries ?? 2;
  }

  async complete(req: CompletionRequest): Promise<CompletionResponse> {
    const model = req.model || this.defaultModel;
    // Anthropic keeps the system prompt out-of-band.
    const system = req.messages
      .filter((m) => m.role === "system")
      .map((m) => m.content)
      .join("\n\n");
    const messages = req.messages
      .filter((m) => m.role !== "system")
      .map((m) => ({ role: m.role, content: m.content }));

    const data = await withRetry(
      () =>
        postJson(
          `${this.baseUrl}/messages`,
          {
            "x-api-key": this.apiKey,
            "anthropic-version": "2023-06-01",
          },
          {
            model,
            system: system || undefined,
            messages,
            temperature: req.temperature,
            max_tokens: req.maxTokens ?? 1024,
            ...req.extra,
          },
          this.timeoutMs,
          this.name,
        ),
      this.maxRetries,
      this.name,
    );
    const block = (data.content ?? []).find((b: any) => b.type === "text");
    const usage = data.usage ?? {};
    return {
      provider: this.name,
      model: data.model ?? model,
      content: block?.text ?? "",
      finishReason: normalizeFinish(data.stop_reason),
      usage: {
        promptTokens: usage.input_tokens ?? 0,
        completionTokens: usage.output_tokens ?? 0,
        totalTokens: (usage.input_tokens ?? 0) + (usage.output_tokens ?? 0),
      },
      raw: data,
    };
  }
}

/* -------------------------------- Ollama ------------------------------- */

export class OllamaProvider implements LLMProvider {
  readonly name = "ollama";
  readonly defaultModel: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;
  private readonly maxRetries: number;

  constructor(cfg: ProviderConfig = {}) {
    this.baseUrl = cfg.baseUrl ?? "http://localhost:11434";
    this.defaultModel = cfg.defaultModel ?? "llama3.1";
    this.timeoutMs = cfg.timeoutMs ?? 120_000;
    this.maxRetries = cfg.maxRetries ?? 1;
  }

  async complete(req: CompletionRequest): Promise<CompletionResponse> {
    const model = req.model || this.defaultModel;
    const data = await withRetry(
      () =>
        postJson(
          `${this.baseUrl}/api/chat`,
          {},
          {
            model,
            messages: req.messages,
            stream: false,
            options: {
              temperature: req.temperature,
              num_predict: req.maxTokens,
              ...req.extra,
            },
          },
          this.timeoutMs,
          this.name,
        ),
      this.maxRetries,
      this.name,
    );
    const promptTokens = data.prompt_eval_count ?? 0;
    const completionTokens = data.eval_count ?? 0;
    return {
      provider: this.name,
      model: data.model ?? model,
      content: data.message?.content ?? "",
      finishReason: normalizeFinish(data.done_reason),
      usage: {
        promptTokens,
        completionTokens,
        totalTokens: promptTokens + completionTokens,
      },
      raw: data,
    };
  }

  async healthCheck(): Promise<boolean> {
    try {
      const res = await fetch(`${this.baseUrl}/api/tags`);
      return res.ok;
    } catch {
      return false;
    }
  }
}

function normalizeFinish(
  reason: string | undefined,
): CompletionResponse["finishReason"] {
  switch (reason) {
    case "stop":
    case "end_turn":
      return "stop";
    case "length":
    case "max_tokens":
      return "length";
    case "content_filter":
      return "content_filter";
    default:
      return reason ? "unknown" : "stop";
  }
}

/* ------------------------------- Registry ------------------------------ */

export interface RegistryOptions {
  /** Ordered list of providers to try, highest priority first. */
  providers: LLMProvider[];
  /**
   * When true, `complete` walks the provider list on failure instead of
   * surfacing the first error. Defaults to true.
   */
  fallback?: boolean;
}

/**
 * Central resolver + fallback router for LLM providers.
 *
 *   const registry = new ProviderRegistry({
 *     providers: [new OpenAIProvider(), new AnthropicProvider(), new OllamaProvider()],
 *   });
 *   const res = await registry.complete({ model: "", messages: [...] });
 */
export class ProviderRegistry {
  private readonly providers: LLMProvider[];
  private readonly fallback: boolean;

  constructor(opts: RegistryOptions) {
    if (!opts.providers.length) {
      throw new Error("ProviderRegistry requires at least one provider");
    }
    const seen = new Set<string>();
    for (const p of opts.providers) {
      if (seen.has(p.name)) {
        throw new Error(`Duplicate provider name: ${p.name}`);
      }
      seen.add(p.name);
    }
    this.providers = [...opts.providers];
    this.fallback = opts.fallback ?? true;
  }

  get(name: string): LLMProvider | undefined {
    return this.providers.find((p) => p.name === name);
  }

  list(): string[] {
    return this.providers.map((p) => p.name);
  }

  register(provider: LLMProvider, priority = 0): void {
    if (this.get(provider.name)) {
      throw new Error(`Provider already registered: ${provider.name}`);
    }
    this.providers.splice(priority, 0, provider);
  }

  /**
   * Runs a completion. If `provider` is given, that provider is tried first;
   * otherwise the registry's priority order is used. With fallback enabled,
   * the next provider is attempted whenever one fails.
   */
  async complete(
    req: CompletionRequest,
    provider?: string,
  ): Promise<CompletionResponse> {
    const order = provider
      ? this.orderWithFirst(provider)
      : this.providers;
    const errors: string[] = [];
    for (const p of order) {
      try {
        return await p.complete(req);
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        errors.push(`${p.name}: ${msg}`);
        if (!this.fallback) throw err;
      }
    }
    throw new ProviderError(
      `All providers failed -> ${errors.join(" | ")}`,
      "registry",
      undefined,
      false,
    );
  }

  private orderWithFirst(name: string): LLMProvider[] {
    const first = this.get(name);
    if (!first) throw new ProviderError(`Unknown provider: ${name}`, "registry");
    return [first, ...this.providers.filter((p) => p.name !== name)];
  }
}
