require "minitest/autorun"
require "webmock/minitest"
require "json"
require_relative "../lib/whitebox"

class TestWhiteboxClient < Minitest::Test
  API_KEY  = "test-api-key-123"
  BASE_URL = "https://whiteboxhq.ai/api/v1"

  def setup
    @client = Whitebox::Client.new(api_key: API_KEY)
  end

  # ── Constructor ──────────────────────────────────────────────

  def test_default_base_url
    client = Whitebox::Client.new(api_key: "key")
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 200, body: '{"models":[]}')
    client.list_models
    assert_requested(:get, "#{BASE_URL}/models")
  end

  def test_custom_base_url
    custom = "https://custom.example.com/api/v1"
    client = Whitebox::Client.new(api_key: "key", base_url: custom)
    stub_request(:get, "#{custom}/models")
      .to_return(status: 200, body: '{"models":[]}')
    client.list_models
    assert_requested(:get, "#{custom}/models")
  end

  def test_sends_auth_header
    stub_request(:get, "#{BASE_URL}/models")
      .with(headers: { "Authorization" => "Bearer #{API_KEY}" })
      .to_return(status: 200, body: '{"models":[]}')
    @client.list_models
    assert_requested(:get, "#{BASE_URL}/models",
      headers: { "Authorization" => "Bearer #{API_KEY}" })
  end

  # ── decide ───────────────────────────────────────────────────

  def test_decide_sends_post_and_returns_decision
    response_body = {
      "id" => "dec_1", "status" => "complete", "value" => "approve",
      "confidence" => 0.92, "verdict" => "ship", "escalated" => false,
      "runs" => [
        { "model" => "gpt-4o", "answer" => "approve", "logprob" => -0.1, "latency_ms" => 200 }
      ],
      "latency_ms" => 500, "cost_usd" => 0.003, "created_at" => "2026-04-27T00:00:00Z",
      "mode" => "standard"
    }

    stub_request(:post, "#{BASE_URL}/decide")
      .with(body: hash_including("input" => "test input", "options" => [ "a", "b" ]))
      .to_return(status: 200, body: JSON.generate(response_body))

    decision = @client.decide(input: "test input", options: [ "a", "b" ])

    assert_instance_of Whitebox::Decision, decision
    assert_equal "dec_1", decision.id
    assert_equal "ship", decision.verdict
    assert_equal 0.92, decision.confidence
    assert_equal 1, decision.runs.size
    assert_instance_of Whitebox::Run, decision.runs.first
    assert_equal "gpt-4o", decision.runs.first.model
  end

  def test_decide_passes_models
    stub_request(:post, "#{BASE_URL}/decide")
      .with(body: hash_including("models" => [ "gpt-4o", "claude-3-5-sonnet" ]))
      .to_return(status: 200, body: JSON.generate(decision_hash))

    @client.decide(input: "x", options: [ "a" ], models: [ "gpt-4o", "claude-3-5-sonnet" ])

    assert_requested(:post, "#{BASE_URL}/decide",
      body: hash_including("models" => [ "gpt-4o", "claude-3-5-sonnet" ]))
  end

  def test_decide_default_params
    stub_request(:post, "#{BASE_URL}/decide")
      .with(body: hash_including("runs" => 7, "threshold" => 0.75, "sync" => true, "mode" => "standard"))
      .to_return(status: 200, body: JSON.generate(decision_hash))

    @client.decide(input: "x", options: [ "a" ])

    assert_requested(:post, "#{BASE_URL}/decide",
      body: hash_including("runs" => 7, "threshold" => 0.75, "sync" => true, "mode" => "standard"))
  end

  # ── decide_fast ──────────────────────────────────────────────

  def test_decide_fast_sends_fast_mode
    stub_request(:post, "#{BASE_URL}/decide")
      .with(body: hash_including("mode" => "fast", "sync" => true))
      .to_return(status: 200, body: JSON.generate(decision_hash))

    decision = @client.decide_fast(input: "x", options: [ "a", "b" ])

    assert_instance_of Whitebox::Decision, decision
    assert_requested(:post, "#{BASE_URL}/decide",
      body: hash_including("mode" => "fast", "sync" => true))
  end

  # ── decide_bulk ──────────────────────────────────────────────

  def test_decide_bulk_sends_items_and_returns_batch
    items = [
      { "input" => "item1", "options" => [ "a", "b" ] },
      { "input" => "item2", "options" => [ "c", "d" ] }
    ]

    stub_request(:post, "#{BASE_URL}/decide/bulk")
      .with(body: hash_including("items" => items))
      .to_return(status: 200, body: JSON.generate(batch_hash))

    batch = @client.decide_bulk(items: items)

    assert_instance_of Whitebox::Batch, batch
    assert_equal "batch_1", batch.id
    assert_equal "processing", batch.status
  end

  def test_decide_bulk_with_webhook
    stub_request(:post, "#{BASE_URL}/decide/bulk")
      .with(body: hash_including("webhook_url" => "https://example.com/hook"))
      .to_return(status: 200, body: JSON.generate(batch_hash))

    @client.decide_bulk(items: [ { "input" => "x" } ], webhook_url: "https://example.com/hook")

    assert_requested(:post, "#{BASE_URL}/decide/bulk",
      body: hash_including("webhook_url" => "https://example.com/hook"))
  end

  # ── get_decision ─────────────────────────────────────────────

  def test_get_decision
    stub_request(:get, "#{BASE_URL}/decisions/dec_1")
      .to_return(status: 200, body: JSON.generate(decision_hash("dec_1")))

    decision = @client.get_decision("dec_1")

    assert_instance_of Whitebox::Decision, decision
    assert_equal "dec_1", decision.id
  end

  # ── list_decisions ───────────────────────────────────────────

  def test_list_decisions
    body = { "decisions" => [ decision_hash("dec_1"), decision_hash("dec_2") ] }

    stub_request(:get, "#{BASE_URL}/decisions?page=1&per_page=20")
      .to_return(status: 200, body: JSON.generate(body))

    decisions = @client.list_decisions

    assert_equal 2, decisions.size
    assert decisions.all? { |d| d.is_a?(Whitebox::Decision) }
    assert_equal "dec_1", decisions[0].id
    assert_equal "dec_2", decisions[1].id
  end

  def test_list_decisions_pagination
    body = { "decisions" => [ decision_hash("dec_3") ] }

    stub_request(:get, "#{BASE_URL}/decisions?page=2&per_page=5")
      .to_return(status: 200, body: JSON.generate(body))

    decisions = @client.list_decisions(page: 2, per_page: 5)

    assert_equal 1, decisions.size
  end

  # ── get_batch ────────────────────────────────────────────────

  def test_get_batch
    stub_request(:get, "#{BASE_URL}/batches/batch_1")
      .to_return(status: 200, body: JSON.generate(batch_hash))

    batch = @client.get_batch("batch_1")

    assert_instance_of Whitebox::Batch, batch
    assert_equal "batch_1", batch.id
  end

  # ── get_batch_results ────────────────────────────────────────

  def test_get_batch_results
    results = { "results" => [ decision_hash("dec_1") ], "total" => 1 }

    stub_request(:get, "#{BASE_URL}/batches/batch_1/results")
      .to_return(status: 200, body: JSON.generate(results))

    data = @client.get_batch_results("batch_1")

    assert_kind_of Hash, data
    assert_equal 1, data["total"]
    assert_equal 1, data["results"].size
  end

  # ── list_reviews ─────────────────────────────────────────────

  def test_list_reviews
    reviews = [ review_hash("rev_1"), review_hash("rev_2") ]

    stub_request(:get, "#{BASE_URL}/reviews")
      .to_return(status: 200, body: JSON.generate(reviews))

    result = @client.list_reviews

    assert_equal 2, result.size
    assert result.all? { |r| r.is_a?(Whitebox::Review) }
    assert_equal "rev_1", result[0].id
  end

  # ── resolve_review ──────────────────────────────────────────

  def test_resolve_review
    resolved = review_hash("rev_1").merge("status" => "resolved")

    stub_request(:patch, "#{BASE_URL}/reviews/rev_1")
      .with(body: hash_including("answer" => "approve"))
      .to_return(status: 200, body: JSON.generate(resolved))

    review = @client.resolve_review("rev_1", answer: "approve")

    assert_instance_of Whitebox::Review, review
    assert_equal "resolved", review.status
  end

  # ── list_models ──────────────────────────────────────────────

  def test_list_models
    body = { "models" => [ "gpt-4o", "claude-3-5-sonnet" ] }

    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 200, body: JSON.generate(body))

    result = @client.list_models

    assert_kind_of Hash, result
    assert_equal [ "gpt-4o", "claude-3-5-sonnet" ], result["models"]
  end

  def test_models_alias
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 200, body: '{"models":[]}')

    assert_equal @client.list_models, @client.models
  end

  # ── Error handling ───────────────────────────────────────────

  def test_401_raises_authentication_error
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 401, body: '{"message":"Unauthorized"}')

    err = assert_raises(Whitebox::AuthenticationError) { @client.list_models }
    assert_equal 401, err.status_code
    assert_equal "Unauthorized", err.message
  end

  def test_402_raises_insufficient_credits_error
    stub_request(:post, "#{BASE_URL}/decide")
      .to_return(status: 402, body: '{"error":"Insufficient credits"}')

    err = assert_raises(Whitebox::InsufficientCreditsError) do
      @client.decide(input: "x", options: [ "a" ])
    end
    assert_equal 402, err.status_code
    assert_equal "Insufficient credits", err.message
  end

  def test_429_raises_rate_limit_error
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 429, body: '{"message":"Rate limited"}',
                 headers: { "Retry-After" => "30" })

    err = assert_raises(Whitebox::RateLimitError) { @client.list_models }
    assert_equal 429, err.status_code
    assert_equal "Rate limited", err.message
  end

  def test_500_raises_generic_error
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 500, body: '{"error":"Internal server error"}')

    err = assert_raises(Whitebox::Error) { @client.list_models }
    assert_equal 500, err.status_code
    assert_equal "Internal server error", err.message
  end

  def test_error_includes_response_body
    stub_request(:get, "#{BASE_URL}/models")
      .to_return(status: 403, body: '{"error":"Forbidden","details":"nope"}')

    err = assert_raises(Whitebox::Error) { @client.list_models }
    assert_equal({ "error" => "Forbidden", "details" => "nope" }, err.response)
  end

  # ── Decision model ──────────────────────────────────────────

  def test_decision_from_hash
    d = Whitebox::Decision.from_hash(decision_hash("dec_x"))

    assert_equal "dec_x", d.id
    assert_equal "complete", d.status
    assert_equal "approve", d.value
    assert_equal "standard", d.mode
  end

  def test_decision_shipped
    d = Whitebox::Decision.from_hash(decision_hash.merge("verdict" => "ship"))
    assert d.shipped?

    d2 = Whitebox::Decision.from_hash(decision_hash.merge("verdict" => "escalate"))
    refute d2.shipped?
  end

  def test_decision_escalated
    d = Whitebox::Decision.from_hash(decision_hash.merge("escalated" => true))
    assert d.escalated?

    d2 = Whitebox::Decision.from_hash(decision_hash.merge("escalated" => false))
    refute d2.escalated?
  end

  # ── Batch model ─────────────────────────────────────────────

  def test_batch_from_hash
    b = Whitebox::Batch.from_hash(batch_hash)

    assert_equal "batch_1", b.id
    assert_equal "processing", b.status
    assert_equal 10, b.total
    assert_equal 3, b.completed
  end

  def test_batch_complete
    b = Whitebox::Batch.from_hash(batch_hash.merge("status" => "complete"))
    assert b.complete?

    b2 = Whitebox::Batch.from_hash(batch_hash)
    refute b2.complete?
  end

  # ── Review model ────────────────────────────────────────────

  def test_review_from_hash
    r = Whitebox::Review.from_hash(review_hash("rev_x"))

    assert_equal "rev_x", r.id
    assert_equal "dec_99", r.decision_id
    assert_equal "pending", r.status
    assert_equal "some input", r.input
    assert_equal [ "a", "b" ], r.options
  end

  private

  def decision_hash(id = "dec_1")
    {
      "id" => id, "status" => "complete", "value" => "approve",
      "confidence" => 0.92, "verdict" => "ship", "escalated" => false,
      "runs" => [
        { "model" => "gpt-4o", "answer" => "approve", "logprob" => -0.1, "latency_ms" => 200 }
      ],
      "latency_ms" => 500, "cost_usd" => 0.003,
      "created_at" => "2026-04-27T00:00:00Z", "mode" => "standard"
    }
  end

  def batch_hash
    {
      "id" => "batch_1", "status" => "processing", "total" => 10,
      "completed" => 3, "failed" => 0, "progress" => 0.3,
      "webhook_url" => nil, "completed_at" => nil,
      "created_at" => "2026-04-27T00:00:00Z"
    }
  end

  def review_hash(id = "rev_1")
    {
      "id" => id, "decision_id" => "dec_99", "status" => "pending",
      "input" => "some input", "options" => [ "a", "b" ],
      "model_votes" => { "gpt-4o" => "a", "claude" => "b" },
      "confidence" => 0.55, "sla_deadline" => "2026-04-28T00:00:00Z",
      "created_at" => "2026-04-27T00:00:00Z"
    }
  end
end
