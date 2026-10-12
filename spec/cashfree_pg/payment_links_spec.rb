# frozen_string_literal: true

RSpec.describe CashfreePg::PaymentLinks do
  let(:client) { build_client }

  it "creates a link with an idempotency key and a JSON amount" do
    stub_request(:post, sandbox_url("/links")).to_return(status: 200, body: fixture("payment_link"))

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
      req.body.include?('"link_amount":10.10') &&
        req.body.include?('"send_sms":false') &&
        !req.body.include?("idempotency_key") &&
        headers_of(req)["x-idempotency-key"] == "link_1"
    end).to have_been_made
    expect(response.link_url).to eq("https://payments-test.cashfree.com/links/link_123")
    expect(response["link_amount"]).to eq(BigDecimal("10.10"))
  end

  it "fetches and cancels a link" do
    cancelled = JSON.parse(fixture("payment_link")).merge("link_status" => "CANCELLED").to_json
    stub_request(:get, sandbox_url("/links/link_123")).to_return(status: 200, body: fixture("payment_link"))
    stub_request(:post, sandbox_url("/links/link_123/cancel")).to_return(status: 200, body: cancelled)

    expect(client.payment_links.fetch("link_123").link_status).to eq("ACTIVE")
    expect(client.payment_links.cancel("link_123").link_status).to eq("CANCELLED")
  end

  it "lists the orders created for a link, filtered by status" do
    stub_request(:get, sandbox_url("/links/link_123/orders?status=PAID"))
      .to_return(status: 200, body: [JSON.parse(fixture("order")).merge("order_status" => "PAID")].to_json)

    orders = client.payment_links.orders("link_123", status: "PAID")

    expect(orders.map(&:order_id)).to eq(["order_123"])
    expect(orders.first.order_status).to eq("PAID")
  end

  it "lists link orders without a filter and rejects a non-array response" do
    stub_request(:get, sandbox_url("/links/link_123/orders")).to_return(status: 200, body: "[]")
    stub_request(:get, sandbox_url("/links/link_9/orders")).to_return(status: 200, body: "{}")

    expect(client.payment_links.orders("link_123")).to eq([])
    expect { client.payment_links.orders("link_9") }.to raise_error(CashfreePg::APIError, /not an array/)
  end
end
