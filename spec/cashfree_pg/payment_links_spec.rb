# frozen_string_literal: true

RSpec.describe CashfreePg::PaymentLinks do
  let(:client) { build_client }
  let(:link) { File.read("spec/fixtures/payment_link.json") }

  it "creates a link and returns it" do
    stub_request(:post, sandbox_url("/links")).to_return(status: 200, body: link)

    response = client.payment_links.create(
      link_id: "link_123",
      link_amount: "10.10",
      link_currency: "INR",
      link_purpose: "Test payment",
      customer_details: { customer_phone: "9999999999" },
      link_notify: { send_sms: false, send_email: false },
      idempotency_key: "link_1"
    )

    expect(a_request(:post, sandbox_url("/links")).with do |req|
      headers = req.headers.transform_keys(&:downcase)
      req.body.include?('"link_amount":10.10') &&
        req.body.include?('"send_sms":false') &&
        headers["x-idempotency-key"] == "link_1"
    end).to have_been_made
    expect(response.link_url).to eq("https://payments-test.cashfree.com/links/link_123")
    expect(response["link_amount"]).to eq(BigDecimal("10.10"))
  end

  it "fetches a link by id" do
    stub_request(:get, sandbox_url("/links/link_123")).to_return(status: 200, body: link)

    expect(client.payment_links.fetch("link_123").link_status).to eq("ACTIVE")
  end

  it "cancels an active link" do
    cancelled = JSON.parse(link).merge("link_status" => "CANCELLED")
    stub_request(:post, sandbox_url("/links/link_123/cancel")).to_return(status: 200, body: cancelled.to_json)

    expect(client.payment_links.cancel("link_123").link_status).to eq("CANCELLED")
  end

  it "rejects a blank link id" do
    expect { client.payment_links.fetch(" ") }.to raise_error(ArgumentError, /link_id/)
  end
end
