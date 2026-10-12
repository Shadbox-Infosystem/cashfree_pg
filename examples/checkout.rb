#!/usr/bin/env ruby
# frozen_string_literal: true

# bundle exec ruby examples/checkout.rb
#
# Always verifies a sample webhook offline.
# Creates a sandbox order and starts UPI intent when CASHFREE_CLIENT_ID
# and CASHFREE_CLIENT_SECRET are set. Refuses production credentials.

require "openssl"
require "securerandom"
require "cashfree_pg"

def webhook_signature(secret, timestamp, raw_body)
  digest = OpenSSL::HMAC.digest("SHA256", secret, "#{timestamp}#{raw_body}")
  [digest].pack("m0")
end

def verify_sample_webhook(secret)
  raw_body = '{"type":"PAYMENT_SUCCESS_WEBHOOK","event_time":"2025-01-15T11:16:10+05:30",' \
             '"data":{"order":{"order_id":"order_123","order_amount":10.10}}}'
  timestamp = (Time.now.to_f * 1000).to_i.to_s
  headers = {
    "x-webhook-timestamp" => timestamp,
    "x-webhook-signature" => webhook_signature(secret, timestamp, raw_body),
    "x-webhook-version" => "2025-01-01"
  }
  event = CashfreePg::Webhook.construct_event(raw_body: raw_body, headers: headers, secret: secret)
  puts "webhook type=#{event.type} version=#{event.version}"
end

def sandbox_checkout(client_id, client_secret)
  client = CashfreePg::Client.new(client_id: client_id, client_secret: client_secret, environment: :sandbox)
  order = client.orders.create(
    order_id: "order_#{SecureRandom.hex(4)}",
    order_amount: "1.00",
    order_currency: "INR",
    customer_details: { customer_id: "cust_test", customer_phone: "9999999999" }
  )
  session = client.payments.upi(order, channel: :intent)
  puts "order_id=#{order.order_id} upi_channel=#{session["channel"]}"
end

sample_secret = "cfsk_example_secret"
verify_sample_webhook(sample_secret)

client_id = ENV.fetch("CASHFREE_CLIENT_ID", nil)
client_secret = ENV.fetch("CASHFREE_CLIENT_SECRET", nil)
if client_id.to_s.empty? || client_secret.to_s.empty?
  puts "sandbox skipped: set CASHFREE_CLIENT_ID and CASHFREE_CLIENT_SECRET"
elsif ENV.fetch("CASHFREE_ENVIRONMENT", "sandbox") == "production"
  warn "sandbox skipped: this example refuses production credentials"
else
  sandbox_checkout(client_id, client_secret)
end
