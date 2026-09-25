# frozen_string_literal: true

RSpec.describe CashfreePg::Webhook do
  let(:secret) { ClientHelper::SECRET }
  let(:timestamp) { "1746427759733" }
  let(:body) do
    '{"type":"PAYMENT_SUCCESS_WEBHOOK","event_time":"2025-01-15T11:16:10+05:30",' \
      '"data":{"order":{"order_id":"order_123","order_amount":10.10},' \
      '"customer_details":{"customer_phone":"9999999999"}}}'
  end

  def signature_for(raw_body, stamp = timestamp, key = secret)
    digest = OpenSSL::HMAC.digest("SHA256", key, "#{stamp}#{raw_body}")
    [digest].pack("m0")
  end

  def headers_for(raw_body, stamp: timestamp, key: secret, version: "2025-01-01")
    {
      "x-webhook-signature" => signature_for(raw_body, stamp, key),
      "x-webhook-timestamp" => stamp,
      "x-webhook-version" => version
    }
  end

  def event_for(raw_body = body, headers: headers_for(raw_body), **options)
    described_class.construct_event(raw_body: raw_body, headers: headers, secret: secret, **options)
  end

  it "verifies a signature and returns type, time, data, and version" do
    event = event_for

    expect(event.type).to eq("PAYMENT_SUCCESS_WEBHOOK")
    expect(event.time).to eq("2025-01-15T11:16:10+05:30")
    expect(event.version).to eq("2025-01-01")
    expect(event.data.dig("order", "order_amount")).to eq(BigDecimal("10.10"))
  end

  it "accepts Rails-style header names" do
    rails = headers_for(body).transform_keys { |key| key.split("-").map(&:capitalize).join("-") }

    expect(event_for(headers: rails).type).to eq("PAYMENT_SUCCESS_WEBHOOK")
  end

  it "accepts a Rack env" do
    rack = headers_for(body).transform_keys { |key| "HTTP_#{key.upcase.tr("-", "_")}" }

    expect(event_for(headers: rack).version).to eq("2025-01-01")
  end

  it "accepts a millisecond timestamp when the window is off" do
    expect(event_for.time).to eq("2025-01-15T11:16:10+05:30")
  end

  it "rejects an old millisecond timestamp when a window is set" do
    expect { event_for(tolerance: 300) }
      .to raise_error(CashfreePg::SignatureVerificationError, /window/)
  end

  it "accepts a current timestamp inside the window" do
    stamp = (Time.now.to_f * 1000).to_i.to_s

    expect(event_for(headers: headers_for(body, stamp: stamp), tolerance: 300).type).to eq("PAYMENT_SUCCESS_WEBHOOK")
  end

  it "parses an unknown event type" do
    raw = { type: "FUTURE_EVENT", event_time: "2025-01-15T11:16:10+05:30", data: { order_id: "order_123" } }.to_json

    expect(event_for(raw, headers: headers_for(raw)).type).to eq("FUTURE_EVENT")
  end

  it "rejects a tampered body, a wrong secret, and a bad signature length" do
    expect { event_for("#{body} ", headers: headers_for(body)) }
      .to raise_error(CashfreePg::SignatureVerificationError, /does not match/)
    expect { described_class.construct_event(raw_body: body, headers: headers_for(body), secret: "other-secret") }
      .to raise_error(CashfreePg::SignatureVerificationError, /does not match/)

    forged = headers_for(body).merge("x-webhook-signature" => "short")
    expect { event_for(headers: forged) }.to raise_error(CashfreePg::SignatureVerificationError, /does not match/)
  end

  it "rejects missing and empty signature headers" do
    missing = headers_for(body).tap { |headers| headers.delete("x-webhook-signature") }
    empty = headers_for(body).merge("x-webhook-signature" => " ")

    expect { event_for(headers: missing) }
      .to raise_error(CashfreePg::SignatureVerificationError, /signature is missing/)
    expect { event_for(headers: empty) }.to raise_error(CashfreePg::SignatureVerificationError, /signature is empty/)
  end

  it "rejects missing and empty timestamps" do
    missing = headers_for(body).tap { |headers| headers.delete("x-webhook-timestamp") }
    empty = headers_for(body).merge("x-webhook-timestamp" => "")

    expect { event_for(headers: missing) }
      .to raise_error(CashfreePg::SignatureVerificationError, /timestamp is missing/)
    expect { event_for(headers: empty) }.to raise_error(CashfreePg::SignatureVerificationError, /timestamp is empty/)
  end

  it "rejects a non-string body and does not leak the secret" do
    expect do
      described_class.construct_event(
        raw_body: { type: "PAYMENT_SUCCESS_WEBHOOK" },
        headers: headers_for(body),
        secret: secret
      )
    end.to raise_error(CashfreePg::SignatureVerificationError, /must be a string/)

    error = begin
      event_for("#{body} ", headers: headers_for(body))
    rescue CashfreePg::SignatureVerificationError => e
      e
    end

    expect(error.message).not_to include(secret)
    expect(error.inspect).not_to include(secret)
    expect(error.inspect).to include("raw_body=[FILTERED]")
  end
end
