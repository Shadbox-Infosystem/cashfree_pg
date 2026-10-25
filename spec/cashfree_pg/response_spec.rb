# frozen_string_literal: true

RSpec.describe CashfreePg::Response do
  subject(:response) do
    described_class.new(
      { "order_id" => "order_123", "hash" => "not-the-ruby-hash", "customer_details" => { "customer_id" => "cust_1" } },
      status: 200,
      request_id: "req_1"
    )
  end

  it "reads fields without hiding Ruby methods" do
    expect(response.order_id).to eq("order_123")
    expect(response["hash"]).to eq("not-the-ruby-hash")
    expect(response.hash).to be_a(Integer)
    expect(response.dig(:customer_details, :customer_id)).to eq("cust_1")
    expect(response.status).to eq(200)
    expect(response.request_id).to eq("req_1")
    expect(response.to_h).to include("order_id" => "order_123")
  end

  it "does not invent readers for missing keys" do
    expect(response).not_to respond_to(:missing)
    expect { response.missing }.to raise_error(NoMethodError)
  end
end
