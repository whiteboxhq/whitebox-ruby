require "net/http"
require "json"
require "uri"

module Whitebox
  class Client
    BASE_URL = "https://whiteboxhq.ai/api/v1"

    def initialize(api_key:, base_url: nil, timeout: 30)
      @api_key = api_key
      @base_url = base_url || BASE_URL
      @timeout = timeout
    end

    # Single decision
    def decide(input:, options:, prompt: nil, runs: 7, threshold: 0.75, sync: true, mode: "standard", models: nil)
      body = {
        input: input,
        options: options,
        prompt: prompt,
        runs: runs,
        threshold: threshold,
        sync: sync,
        mode: mode
      }
      body[:models] = models if models

      data = request(:post, "/decide", body)
      Decision.from_hash(data)
    end

    # Fast mode: 3 runs, 2 models, sync
    def decide_fast(input:, options:, prompt: nil, threshold: 0.75)
      decide(input: input, options: options, prompt: prompt, threshold: threshold, mode: "fast", sync: true)
    end

    # Bulk decisions
    def decide_bulk(items:, prompt: nil, options: nil, runs: 7, threshold: 0.75, webhook_url: nil)
      body = {
        items: items,
        prompt: prompt,
        options: options,
        runs: runs,
        threshold: threshold,
        webhook_url: webhook_url
      }.compact

      data = request(:post, "/decide/bulk", body)
      Batch.from_hash(data)
    end

    # Get a single decision
    def get_decision(id)
      data = request(:get, "/decisions/#{id}")
      Decision.from_hash(data)
    end

    # List decisions
    def list_decisions(page: 1, per_page: 20)
      data = request(:get, "/decisions?page=#{page}&per_page=#{per_page}")
      (data["decisions"] || []).map { |d| Decision.from_hash(d) }
    end

    # Get batch status
    def get_batch(id)
      data = request(:get, "/batches/#{id}")
      Batch.from_hash(data)
    end

    # Get batch results
    def get_batch_results(id)
      request(:get, "/batches/#{id}/results")
    end

    # List pending reviews
    def list_reviews
      data = request(:get, "/reviews")
      (data.is_a?(Array) ? data : []).map { |r| Review.from_hash(r) }
    end

    # Resolve a review
    def resolve_review(id, answer:)
      data = request(:patch, "/reviews/#{id}", { answer: answer })
      Review.from_hash(data)
    end

    # List supported models
    def list_models
      request(:get, "/models")
    end
    alias_method :models, :list_models

    private

    def request(method, path, body = nil)
      uri = URI("#{@base_url}#{path}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = @timeout
      http.open_timeout = 10

      req = case method
      when :get    then Net::HTTP::Get.new(uri)
      when :post   then Net::HTTP::Post.new(uri)
      when :patch  then Net::HTTP::Patch.new(uri)
      when :delete then Net::HTTP::Delete.new(uri)
      end

      req["Authorization"] = "Bearer #{@api_key}"
      req["Content-Type"] = "application/json"
      req["Accept"] = "application/json"

      if body
        req.body = JSON.generate(body)
      end

      response = http.request(req)
      handle_response(response)
    end

    def handle_response(response)
      body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        { "error" => response.body }
      end

      case response.code.to_i
      when 200..299
        body
      when 401
        raise AuthenticationError.new(
          body["message"] || "Unauthorized",
          status_code: 401, response: body
        )
      when 402
        raise InsufficientCreditsError.new(
          body["error"] || "Insufficient credits",
          status_code: 402, response: body
        )
      when 429
        raise RateLimitError.new(
          body["message"] || "Rate limited",
          status_code: 429, response: body,
          retry_after: response["Retry-After"]&.to_i
        )
      else
        raise Error.new(
          body["error"] || body["message"] || "Request failed (#{response.code})",
          status_code: response.code.to_i, response: body
        )
      end
    end
  end
end
