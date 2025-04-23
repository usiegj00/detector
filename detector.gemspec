require_relative "lib/detector/version"

Gem::Specification.new do |spec|
  spec.name          = "detector"
  spec.version       = Detector::VERSION
  spec.authors = ["Jonathan Siegel"]
  spec.email = ["<248302+usiegj00@users.noreply.github.com>"]

  spec.summary       = "Detect and analyze various database systems"
  spec.description   = "A system manager's toolkit to detect and analyze various database systems like Postgres, MySQL, Redis, etc."
  spec.homepage      = "https://github.com/usiegj00/detector"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.6.0")

  # spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files         = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  spec.bindir        = "bin"
  spec.executables   = ["detector"]
  spec.require_paths = ["lib"]

  spec.add_dependency "uri", "~> 0.11.0"
  spec.add_dependency "pg", "~> 1.4"
  spec.add_dependency "redis", "~> 5.0"
  spec.add_dependency "mysql2", "~> 0.5"
  spec.add_dependency "resolv", "~> 0.2.1"
  spec.add_dependency "bigdecimal", "~> 3.1"
  spec.add_dependency "net-smtp", "~> 0.3.3"
  spec.add_dependency "geocoder", "~> 1.8"
  
  spec.add_development_dependency "rspec", "~> 3.10"
end 