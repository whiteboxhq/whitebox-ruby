require_relative "lib/whitebox/version"

Gem::Specification.new do |spec|
  spec.name          = "whitebox"
  spec.version       = Whitebox::VERSION
  spec.authors       = ["WhiteBox"]
  spec.email         = ["hello@whiteboxhq.ai"]

  spec.summary       = "WhiteBox SDK - AI Decision Observability"
  spec.description   = "Run every AI classification through multiple models. Measure agreement. Ship with confidence or escalate to a human."
  spec.homepage      = "https://whiteboxhq.ai"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ja-roque/whitebox"
  spec.metadata["changelog_uri"]   = "https://github.com/ja-roque/whitebox/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  # Zero dependencies - uses only stdlib (net/http, json, uri)
end
