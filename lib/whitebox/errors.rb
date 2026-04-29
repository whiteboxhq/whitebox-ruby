module Whitebox
  class Error < StandardError
    attr_reader :status_code, :response

    def initialize(message, status_code: nil, response: nil)
      super(message)
      @status_code = status_code
      @response = response
    end
  end

  class AuthenticationError < Error; end
  class InsufficientCreditsError < Error; end

  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, retry_after: nil, **kwargs)
      super(message, **kwargs)
      @retry_after = retry_after
    end
  end
end
