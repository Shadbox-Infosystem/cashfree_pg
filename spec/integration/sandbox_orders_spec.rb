# frozen_string_literal: true

RSpec.describe "sandbox orders" do
  it "creates an order, starts UPI intent, and fetches payments" do
    id = ENV.fetch("CASHFREE_CLIENT_ID", nil)
    secret = ENV.fetch("CASHFREE_CLIENT_SECRET", nil)
    skip "sandbox credentials are not set" if id.to_s.empty? || secret.to_s.empty?
    skip "sandbox specs refuse production credentials" if ENV["CASHFREE_ENVIRONMENT"] == "production"

    WebMock.allow_net_connect!
    client = CashfreePg::Client.new(client_id: id, client_secret: secret, environment: :sandbox)
    order_id = "order_#{SecureRandom.hex(6)}"

    order = client.orders.create(
      order_id: order_id,
      order_amount: "1.00",
      order_currency: "INR",
      customer_details: { customer_id: "cust_test", customer_phone: "9999999999" }
    )
    session = client.payments.upi(order, channel: :intent)
    payments = client.payments.list(order_id)

    expect(order.payment_session_id).not_to be_empty
    expect(session).to be_a(CashfreePg::Response)
    expect(payments).to be_an(Array)
  ensure
    WebMock.disable_net_connect!
  end
end
