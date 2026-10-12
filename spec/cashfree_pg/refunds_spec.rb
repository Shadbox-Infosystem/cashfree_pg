# frozen_string_literal: true

RSpec.describe CashfreePg::Refunds do
  let(:client) { build_client }

  it "creates a refund with a merchant refund id and a JSON amount" do
    stub_request(:post, sandbox_url("/orders/order_123/refunds")).to_return(status: 200, body: fixture("refund"))

    response = client.refunds.create(
      "order_123",
      refund_amount: "10.10",
      refund_id: "refund_00912",
      refund_note: "SUCCESS",
      idempotency_key: "ref_1"
    )

    expect(a_request(:post, sandbox_url("/orders/order_123/refunds")).with do |req|
      req.body.include?('"refund_amount":10.10') &&
        req.body.include?('"refund_id":"refund_00912"') &&
        headers_of(req)["x-idempotency-key"] == "ref_1"
    end).to have_been_made.once
    expect(response.refund_status).to eq("SUCCESS")
  end

  it "fetches one refund and lists the API array unchanged" do
    stub_request(:get, sandbox_url("/orders/order_123/refunds/refund_00912"))
      .to_return(status: 200, body: fixture("refund"))
    stub_request(:get, sandbox_url("/orders/order_123/refunds")).to_return(status: 200, body: "[#{fixture("refund")}]")

    expect(client.refunds.fetch("order_123", "refund_00912").refund_id).to eq("refund_00912")

    listed = client.refunds.list("order_123").to_h
    expect(listed).to be_an(Array)
    expect(listed.first["refund_amount"]).to eq(BigDecimal("10.10"))
  end

  it "maps a duplicate refund id to ConflictError" do
    stub_request(:post, sandbox_url("/orders/order_123/refunds")).to_return(
      status: 409,
      body: { type: "invalid_request_error", code: "refund_id_invalid", message: "refund exists" }.to_json
    )

    expect { client.refunds.create("order_123", refund_amount: "10.10", refund_id: "refund_00912") }
      .to raise_error(CashfreePg::ConflictError, /refund_id_invalid/)
  end
end
