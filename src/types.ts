export type Scenario = {
  id: string;
  agent: string;
  locales: Record<string, ScenarioLocale>;
};

export type ScenarioLocale = {
  input: string;
  expect: {
    toolCall: {
      name: string;
    };
  };
};

export type ToolCall = {
  name: string;
  arguments?: unknown;
};

export type TargetResponse = {
  text: string;
  toolCalls: ToolCall[];
  structured: unknown;
};

export type LocaleResult = {
  locale: string;
  status: "pass" | "fail";
  detail: string;
  response?: TargetResponse;
};

export type RunResult = {
  scenarioId: string;
  target: string;
  results: LocaleResult[];
};
