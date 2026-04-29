module Whitebox
  Run = Data.define(:model, :answer, :logprob, :latency_ms) do
    def self.from_hash(h)
      new(
        model: h["model"],
        answer: h["answer"],
        logprob: h["logprob"],
        latency_ms: h["latency_ms"]
      )
    end
  end

  Decision = Data.define(:id, :status, :value, :confidence, :verdict, :escalated, :runs, :latency_ms, :cost_usd, :created_at, :mode) do
    def self.from_hash(h)
      new(
        id: h["id"],
        status: h["status"],
        value: h["value"],
        confidence: h["confidence"],
        verdict: h["verdict"],
        escalated: h["escalated"],
        runs: (h["runs"] || []).map { |r| Run.from_hash(r) },
        latency_ms: h["latency_ms"],
        cost_usd: h["cost_usd"],
        created_at: h["created_at"],
        mode: h["mode"]
      )
    end

    def shipped? = verdict == "ship"
    def escalated? = escalated == true
  end

  Batch = Data.define(:id, :status, :total, :completed, :failed, :progress, :webhook_url, :completed_at, :created_at) do
    def self.from_hash(h)
      new(
        id: h["id"],
        status: h["status"],
        total: h["total"],
        completed: h["completed"],
        failed: h["failed"],
        progress: h["progress"],
        webhook_url: h["webhook_url"],
        completed_at: h["completed_at"],
        created_at: h["created_at"]
      )
    end

    def complete? = status == "complete"
  end

  Review = Data.define(:id, :decision_id, :status, :input, :options, :model_votes, :confidence, :sla_deadline, :created_at) do
    def self.from_hash(h)
      new(
        id: h["id"],
        decision_id: h["decision_id"],
        status: h["status"],
        input: h["input"],
        options: h["options"],
        model_votes: h["model_votes"],
        confidence: h["confidence"],
        sla_deadline: h["sla_deadline"],
        created_at: h["created_at"]
      )
    end
  end
end
