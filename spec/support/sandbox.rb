# frozen_string_literal: true

# Examples tagged `:sandbox` call the real Cashfree sandbox. They skip without
# credentials and never run with production settings.
module SandboxHelper
  def sandbox_client
    id = ENV.fetch("CASHFREE_CLIENT_ID", nil)
    secret = ENV.fetch("CASHFREE_CLIENT_SECRET", nil)
    skip "sandbox credentials are not set" if id.to_s.empty? || secret.to_s.empty?
    skip "sandbox specs refuse production credentials" if ENV.fetch("CASHFREE_ENVIRONMENT", nil) == "production"

    CashfreePg::Client.new(client_id: id, client_secret: secret, environment: :sandbox)
  end
end

RSpec.configure do |config|
  config.include SandboxHelper, :sandbox
  config.around(:each, :sandbox) do |example|
    WebMock.allow_net_connect!
    example.run
  ensure
    WebMock.disable_net_connect!
  end
end
