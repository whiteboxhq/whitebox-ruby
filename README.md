# WhiteBox Ruby SDK

Official Ruby client for [WhiteBox](https://whiteboxhq.ai) -- AI Decision Observability.

Run every AI classification through multiple models. Measure agreement. Ship with confidence or escalate to a human.

## Install

```
gem install whitebox
```

Or add to your Gemfile:

```ruby
gem "whitebox"
```

## Quick Start

```ruby
require "whitebox"

wb = Whitebox::Client.new(api_key: "wb_live_...")

# Classify something
result = wb.decide(
  input: "dish soap, lemon scent, 750ml",
  options: ["personal_care", "household_cleaning", "kitchen", "grocery"],
  prompt: "Classify the product into one category"
)

puts result.value       # "household_cleaning"
puts result.confidence  # 0.94
puts result.verdict     # "ship"
puts result.runs.size   # 7
```

## Fast Mode

3 runs, 2 models, sub-second latency:

```ruby
result = wb.decide_fast(
  input: "my card was charged twice",
  options: ["billing", "fraud", "shipping", "general"]
)
```

## Custom Models

Pick which models vote on your decision:

```ruby
result = wb.decide(
  input: "suspicious login from new device",
  options: ["legitimate", "suspicious", "fraudulent"],
  models: ["openai/gpt-4o", "anthropic/claude-sonnet-4", "mistralai/mistral-large"],
  runs: 9
)
```

## Bulk Decisions

Submit up to 100 items at once:

```ruby
batch = wb.decide_bulk(
  items: [
    { input: "dish soap, lemon, 750ml" },
    { input: "rose hand cream, 100ml" },
    { input: "bamboo cutting board" },
  ],
  options: ["personal_care", "household_cleaning", "kitchen"],
  webhook_url: "https://yourapp.com/webhooks/whitebox"
)

puts batch.id       # UUID
puts batch.status   # "processing"
puts batch.total    # 3

# Poll for results
loop do
  b = wb.get_batch(batch.id)
  break if b.complete?
  sleep 2
end

results = wb.get_batch_results(batch.id)
```

## Human Review

List and resolve escalated decisions:

```ruby
reviews = wb.list_reviews
reviews.each do |r|
  puts "#{r.input} -- confidence: #{r.confidence}"
end

wb.resolve_review(reviews.first.id, answer: "household_cleaning")
```

## Error Handling

```ruby
begin
  wb.decide(input: "test", options: ["a", "b"])
rescue Whitebox::AuthenticationError
  puts "Bad API key"
rescue Whitebox::InsufficientCreditsError
  puts "Buy more credits"
rescue Whitebox::RateLimitError => e
  puts "Rate limited, retry in #{e.retry_after}s"
rescue Whitebox::Error => e
  puts "Error: #{e.message} (#{e.status_code})"
end
```

## Links

- Documentation: https://whiteboxhq.ai/api-docs
- Dashboard: https://whiteboxhq.ai/dashboard
- Supported models: https://whiteboxhq.ai/api/v1/models
