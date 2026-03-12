/**
 * Tests for bestEffort delivery skipping the descendant subagent wait.
 *
 * Bug: dispatchCronDelivery blocks for the full cron timeoutMs when an
 * orchestrator cron job spawns subagents and uses delivery.bestEffort: true.
 * The waitForDescendantSubagentSummary call and activeSubagentRuns > 0
 * early-return gate both fire unconditionally when workers are active,
 * regardless of whether bestEffort delivery is configured.
 *
 * Expected: when deliveryBestEffort is true, skip the subagent wait entirely
 * and deliver the orchestrator's own output immediately.
 */

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

// --- Module mocks (must be hoisted before imports) ---

vi.mock("../../agents/subagent-registry.js", () => ({
  countActiveDescendantRuns: vi.fn().mockReturnValue(0),
}));

vi.mock("../../infra/outbound/deliver.js", () => ({
  deliverOutboundPayloads: vi.fn().mockResolvedValue([{ ok: true }]),
}));

vi.mock("../../infra/outbound/identity.js", () => ({
  resolveAgentOutboundIdentity: vi.fn().mockReturnValue({}),
}));

vi.mock("../../infra/outbound/session-context.js", () => ({
  buildOutboundSessionContext: vi.fn().mockReturnValue({}),
}));

vi.mock("../../cli/outbound-send-deps.js", () => ({
  createOutboundSendDeps: vi.fn().mockReturnValue({}),
}));

vi.mock("../../logger.js", () => ({
  logWarn: vi.fn(),
}));

vi.mock("./subagent-followup.js", () => ({
  expectsSubagentFollowup: vi.fn().mockReturnValue(false),
  isLikelyInterimCronMessage: vi.fn().mockReturnValue(false),
  readDescendantSubagentFallbackReply: vi.fn().mockResolvedValue(undefined),
  waitForDescendantSubagentSummary: vi.fn().mockResolvedValue(undefined),
}));

// Import after mocks
import { countActiveDescendantRuns } from "../../agents/subagent-registry.js";
import { deliverOutboundPayloads } from "../../infra/outbound/deliver.js";
import { dispatchCronDelivery } from "./delivery-dispatch.js";
import type { DeliveryTargetResolution } from "./delivery-target.js";
import type { RunCronAgentTurnResult } from "./run.js";
import {
  expectsSubagentFollowup,
  isLikelyInterimCronMessage,
  readDescendantSubagentFallbackReply,
  waitForDescendantSubagentSummary,
} from "./subagent-followup.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeResolvedDelivery(): Extract<DeliveryTargetResolution, { ok: true }> {
  return {
    ok: true,
    channel: "telegram",
    to: "123456",
    accountId: undefined,
    threadId: undefined,
    mode: "explicit",
  };
}

function makeWithRunSession() {
  return (
    result: Omit<RunCronAgentTurnResult, "sessionId" | "sessionKey">,
  ): RunCronAgentTurnResult => ({
    ...result,
    sessionId: "test-session-id",
    sessionKey: "test-session-key",
  });
}

function makeBaseParams(overrides: {
  synthesizedText?: string;
  deliveryRequested?: boolean;
  deliveryBestEffort?: boolean;
}) {
  const resolvedDelivery = makeResolvedDelivery();
  return {
    cfg: {} as never,
    cfgWithAgentDefaults: {} as never,
    deps: {} as never,
    job: {
      id: "test-job",
      name: "Test Job",
      deleteAfterRun: false,
      payload: { kind: "agentTurn", message: "hello" },
    } as never,
    agentId: "main",
    agentSessionKey: "agent:main",
    runSessionId: "run-123",
    runStartedAt: Date.now(),
    runEndedAt: Date.now(),
    timeoutMs: 30_000,
    resolvedDelivery,
    deliveryRequested: overrides.deliveryRequested ?? true,
    skipHeartbeatDelivery: false,
    deliveryBestEffort: overrides.deliveryBestEffort ?? false,
    deliveryPayloadHasStructuredContent: false,
    deliveryPayloads: overrides.synthesizedText ? [{ text: overrides.synthesizedText }] : [],
    synthesizedText: overrides.synthesizedText ?? "on it",
    summary: overrides.synthesizedText ?? "on it",
    outputText: overrides.synthesizedText ?? "on it",
    telemetry: undefined,
    abortSignal: undefined,
    isAborted: () => false,
    abortReason: () => "aborted",
    withRunSession: makeWithRunSession(),
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("dispatchCronDelivery — bestEffort skips descendant subagent wait", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(countActiveDescendantRuns).mockReturnValue(0);
    vi.mocked(expectsSubagentFollowup).mockReturnValue(false);
    vi.mocked(isLikelyInterimCronMessage).mockReturnValue(false);
    vi.mocked(readDescendantSubagentFallbackReply).mockResolvedValue(undefined);
    vi.mocked(waitForDescendantSubagentSummary).mockResolvedValue(undefined);
  });

  afterEach(() => {
    vi.unstubAllEnvs();
  });

  it("does not call waitForDescendantSubagentSummary when bestEffort is true and subagents are active", async () => {
    // Active descendant subagents exist
    vi.mocked(countActiveDescendantRuns).mockReturnValue(3);

    const params = makeBaseParams({
      synthesizedText: "Fired off 3 worker agents.",
      deliveryBestEffort: true,
    });
    const state = await dispatchCronDelivery(params);

    // waitForDescendantSubagentSummary must NOT be called — bestEffort skips the wait
    expect(waitForDescendantSubagentSummary).not.toHaveBeenCalled();

    // Delivery should still complete (not suppressed by the activeSubagentRuns > 0 early-return)
    expect(state.deliveryAttempted).toBe(true);
    expect(state.delivered).toBe(true);
    expect(deliverOutboundPayloads).toHaveBeenCalledTimes(1);
  });

  it("does not suppress interim-message delivery when bestEffort is true and descendants are active", async () => {
    // Active descendant subagents exist and text matches interim cron message
    vi.mocked(countActiveDescendantRuns).mockReturnValue(2);
    vi.mocked(isLikelyInterimCronMessage).mockReturnValue(true);

    const params = makeBaseParams({
      synthesizedText: "on it",
      deliveryBestEffort: true,
    });
    const state = await dispatchCronDelivery(params);

    // bestEffort should bypass the interim-message suppression gate
    expect(state.delivered).toBe(true);
    expect(state.deliveryAttempted).toBe(true);
    expect(deliverOutboundPayloads).toHaveBeenCalledTimes(1);
  });

  it("delivers orchestrator output immediately without blocking when bestEffort is true", async () => {
    // Active descendant subagents exist
    vi.mocked(countActiveDescendantRuns).mockReturnValue(2);

    const params = makeBaseParams({
      synthesizedText: "Executor dispatched workers to handle the backlog.",
      deliveryBestEffort: true,
    });
    const state = await dispatchCronDelivery(params);

    // Should deliver the orchestrator's own text immediately
    expect(state.delivered).toBe(true);
    expect(deliverOutboundPayloads).toHaveBeenCalledWith(
      expect.objectContaining({
        payloads: [{ text: "Executor dispatched workers to handle the backlog." }],
      }),
    );
  });
});
