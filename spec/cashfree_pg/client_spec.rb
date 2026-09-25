# frozen_string_literal: true

require "pp"

RSpec.describe CashfreePg::Client do
  it "hides the secret in inspect, to_s, and pp" do
    client = build_client

    expect(client.inspect).to include("client_secret=[FILTERED]")
    expect(client.inspect).not_to include(ClientHelper::SECRET)
    expect(client.to_s).not_to include(ClientHelper::SECRET)
    expect(PP.pp(client, +"")).not_to include(ClientHelper::SECRET)
  end

  it "uses the sandbox and production hosts" do
    expect(build_client.base_url).to eq("https://sandbox.cashfree.com/pg")
    expect(build_client(environment: :production).base_url).to eq("https://api.cashfree.com/pg")
  end

  it "rejects a custom base URL unless it is an explicit https test URL" do
    expect { build_client(base_url: "https://example.test") }
      .to raise_error(ArgumentError, /allow_custom_base_url/)
    expect { build_client(base_url: "http://example.test", allow_custom_base_url: true) }
      .to raise_error(ArgumentError, /https/)
    expect(build_client(base_url: "https://example.test/", allow_custom_base_url: true).base_url)
      .to eq("https://example.test")
  end

  it "rejects a blank secret and an unknown environment" do
    expect { build_client(client_secret: "  ") }.to raise_error(ArgumentError, /client_secret/)
    expect { build_client(environment: :live) }.to raise_error(ArgumentError, /environment/)
  end

  it "verifies TLS and does not follow redirects or log" do
    connection = build_client.instance_variable_get(:@connection)
    names = connection.builder.handlers.map(&:name)

    expect(connection.ssl.verify).to be(true)
    expect(names.grep(/Logger|FollowRedirects/)).to be_empty
  end
end
