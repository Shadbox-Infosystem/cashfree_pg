# frozen_string_literal: true

RSpec.describe CashfreePg::Resource do
  let(:client) { build_client }

  it "encodes ids so they stay one path segment" do
    stub_request(:get, sandbox_url("/orders/order%20a%3Fb")).to_return(status: 200, body: "{}")

    client.orders.fetch("order a?b")

    expect(a_request(:get, sandbox_url("/orders/order%20a%3Fb"))).to have_been_made
  end

  it "rejects blank ids and ids containing a slash on every resource" do
    expect { client.orders.fetch(" ") }.to raise_error(ArgumentError, /order_id is required/)
    expect { client.refunds.fetch("order_123", "") }.to raise_error(ArgumentError, /refund_id is required/)
    expect { client.payment_links.cancel(nil) }.to raise_error(ArgumentError, /link_id is required/)
    expect { client.payments.fetch("order_123", "../x") }.to raise_error(ArgumentError, /cf_payment_id must not/)
    expect { client.payments.list("a/b") }.to raise_error(ArgumentError, /order_id must not contain a slash/)
  end
end
