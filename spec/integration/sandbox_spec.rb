# frozen_string_literal: true

RSpec.describe "Cashfree sandbox", :sandbox do
  let(:client) { sandbox_client }

  it "creates an order, starts UPI intent, and fetches payments" do
    order_id = "order_#{SecureRandom.hex(6)}"
    order = client.orders.create(
      order_id: order_id,
      order_amount: "1.00",
      order_currency: "INR",
      customer_details: { customer_id: "cust_test", customer_phone: "9999999999" }
    )

    expect(order.payment_session_id).not_to be_empty
    expect(client.payments.upi(order, channel: :intent).channel).to eq("link")
    expect(client.payments.list(order_id)).to be_an(Array)
  end

  it "terminates an unpaid order" do
    order_id = "order_#{SecureRandom.hex(6)}"
    client.orders.create(
      order_id: order_id,
      order_amount: "1.00",
      order_currency: "INR",
      customer_details: { customer_id: "cust_test", customer_phone: "9999999999" }
    )

    expect(client.orders.terminate(order_id).order_status).to eq("TERMINATED").or eq("TERMINATION_REQUESTED")
  end

  it "creates, fetches, and cancels a payment link" do
    link_id = "link_#{SecureRandom.hex(6)}"
    link = client.payment_links.create(
      link_id: link_id,
      link_amount: "1.00",
      link_currency: "INR",
      link_purpose: "Test payment",
      customer_details: { customer_phone: "9999999999", customer_email: "test@example.com" },
      link_notify: { send_sms: false, send_email: false }
    )

    expect(link.link_url).not_to be_empty
    expect(client.payment_links.fetch(link_id).link_id).to eq(link_id)
    expect(client.payment_links.orders(link_id, status: "ALL")).to be_an(Array)
    expect(client.payment_links.cancel(link_id).link_status).to eq("CANCELLED")
  end

  it "refunds a paid sandbox order" do
    order_id = ENV.fetch("CASHFREE_PAID_ORDER_ID", nil)
    skip "set CASHFREE_PAID_ORDER_ID to refund a paid sandbox order" if order_id.to_s.empty?

    refund_id = "refund_#{SecureRandom.hex(4)}"
    refund = client.refunds.create(order_id, refund_amount: "1.00", refund_id: refund_id, refund_note: "SUCCESS")

    expect(refund.refund_id).to eq(refund_id)
    expect(client.refunds.fetch(order_id, refund_id).refund_id).to eq(refund_id)
  end
end
