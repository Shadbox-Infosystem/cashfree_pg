# frozen_string_literal: true

RSpec.describe "sandbox payment links and refunds" do
  def sandbox_client
    id = ENV.fetch("CASHFREE_CLIENT_ID", nil)
    secret = ENV.fetch("CASHFREE_CLIENT_SECRET", nil)
    skip "sandbox credentials are not set" if id.to_s.empty? || secret.to_s.empty?
    skip "sandbox specs refuse production credentials" if ENV.fetch("CASHFREE_ENVIRONMENT", nil) == "production"

    CashfreePg::Client.new(client_id: id, client_secret: secret, environment: :sandbox)
  end

  it "creates and fetches a payment link" do
    WebMock.allow_net_connect!
    client = sandbox_client
    link_id = "link_#{SecureRandom.hex(6)}"

    link = client.payment_links.create(
      link_id: link_id,
      link_amount: "1.00",
      link_currency: "INR",
      link_purpose: "Test payment",
      customer_details: { customer_phone: "9999999999", customer_email: "test@example.com" },
      link_notify: { send_sms: false, send_email: false }
    )
    fetched = client.payment_links.fetch(link_id)

    expect(link.link_url).not_to be_empty
    expect(fetched.link_id).to eq(link_id)
  ensure
    WebMock.disable_net_connect!
  end

  it "refunds a paid sandbox order" do
    order_id = ENV.fetch("CASHFREE_PAID_ORDER_ID", nil)
    skip "set CASHFREE_PAID_ORDER_ID to refund a paid sandbox order" if order_id.to_s.empty?

    WebMock.allow_net_connect!
    client = sandbox_client
    refund_id = "refund_#{SecureRandom.hex(4)}"

    refund = client.refunds.create(
      order_id,
      refund_amount: "1.00",
      refund_id: refund_id,
      refund_note: "SUCCESS"
    )

    expect(refund.refund_id).to eq(refund_id)
  ensure
    WebMock.disable_net_connect!
  end
end
