# frozen_string_literal: true

require_relative "lib/cashfree_pg/version"

Gem::Specification.new do |spec|
  spec.name = "cashfree_pg"
  spec.version = CashfreePg::VERSION
  spec.authors = ["Muballigh Faraz"]
  spec.email = ["support@shadbox.com"]

  spec.summary = "Unofficial Ruby client for the Cashfree Payments API."
  spec.description = "A small, well-tested Ruby client for Cashfree Payment Gateway APIs: orders, payments, " \
                     "UPI, refunds, payment links and webhook verification. Instance-based, thread-safe, " \
                     "with API version pinning, exact money handling and secrets redacted by default. " \
                     "Not affiliated with or endorsed by Cashfree Payments."
  spec.homepage = "https://github.com/Shadbox-Infosystem/cashfree_pg"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Only tracked files under these paths are packaged; see the package:check rake task.
  spec.files = IO.popen(%w[git ls-files -z -- lib sig README.md LICENSE.txt CHANGELOG.md],
                        chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true)
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0", "< 3"
end
