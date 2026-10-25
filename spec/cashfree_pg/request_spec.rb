# frozen_string_literal: true

RSpec.describe CashfreePg::Request do
  let(:client) { build_client }

  describe "headers and money" do
    it "sends auth, version, request id, and a plain JSON amount" do
      stub_request(:post, sandbox_url("/orders")).to_return(
        status: 200,
        body: { order_id: "order_123", order_amount: 10.10 }.to_json,
        headers: { "Content-Type" => "application/json", "x-request-id" => "cf_req" }
      )

      response = client.post("/orders", { order_amount: BigDecimal("10.10"), order_currency: "INR" })

      expect(a_request(:post, sandbox_url("/orders")).with do |req|
        headers = headers_of(req)
        body = req.body
        headers["x-client-id"] == "cf_test_id" &&
          headers["x-client-secret"] == ClientHelper::SECRET &&
          headers["x-api-version"] == "2025-01-01" &&
          headers["x-request-id"].to_s != "" &&
          headers["user-agent"].start_with?("cashfree_pg/") &&
          body.include?('"order_amount":10.10') &&
          !body.include?("e2")
      end).to have_been_made.once

      expect(response.order_id).to eq("order_123")
      expect(response["order_amount"]).to eq(BigDecimal("10.10"))
      expect(response.request_id).to eq("cf_req")
      expect(response.status).to eq(200)
    end

    it "skips only the secret headers" do
      stub_request(:post, sandbox_url("/orders/sessions")).to_return(status: 200, body: "{}")

      client.post("/orders/sessions", { payment_method: { upi: {} } }, skip_auth: true)

      expect(a_request(:post, sandbox_url("/orders/sessions")).with do |req|
        headers = headers_of(req)
        !headers.key?("x-client-id") &&
          !headers.key?("x-client-secret") &&
          headers["x-api-version"] == "2025-01-01"
      end).to have_been_made
    end

    it "sends an idempotency key and does not retry a failed POST" do
      stub_request(:post, sandbox_url("/links")).to_return(status: 500, body: { message: "down" }.to_json)

      expect { client.post("/links", { link_amount: "1.00" }, idempotency_key: "key_1") }
        .to raise_error(CashfreePg::APIError)

      expect(a_request(:post, sandbox_url("/links")).with do |req|
        headers_of(req)["x-idempotency-key"] == "key_1"
      end).to have_been_made.once
    end
  end

  describe "errors" do
    {
      400 => CashfreePg::InvalidRequestError,
      401 => CashfreePg::AuthenticationError,
      403 => CashfreePg::PermissionError,
      404 => CashfreePg::NotFoundError,
      409 => CashfreePg::ConflictError,
      422 => CashfreePg::ValidationError,
      429 => CashfreePg::RateLimitError,
      500 => CashfreePg::APIError,
      302 => CashfreePg::APIError
    }.each do |status, error_class|
      it "maps HTTP #{status} to #{error_class.name}" do
        stub_request(:get, sandbox_url("/orders/x")).to_return(
          status: status,
          body: { type: "api_error", code: "bad", message: "nope", client_secret: ClientHelper::SECRET }.to_json,
          headers: { "Location" => "http://evil.test/steal" }
        )
        stub_request(:get, "http://evil.test/steal")

        expect { client.get("/orders/x") }.to raise_error(error_class) { |error|
          expect(error.status).to eq(status)
          expect(error.code).to eq("bad")
          expect(error.message).to include("status=#{status}", "request_id=")
          expect(error.message).not_to include(ClientHelper::SECRET)
          expect(error.inspect).not_to include(ClientHelper::SECRET)
          expect(error.raw_body).to include(ClientHelper::SECRET)
        }

        expect(a_request(:get, "http://evil.test/steal")).not_to have_been_made
      end
    end

    it "filters a secret that Cashfree echoes in the error message" do
      stub_request(:get, sandbox_url("/orders/x")).to_return(
        status: 400,
        body: { message: "leaked #{ClientHelper::SECRET}" }.to_json
      )

      expect { client.get("/orders/x") }.to raise_error(CashfreePg::InvalidRequestError, /\[FILTERED\]/)
    end

    it "raises TimeoutError once when a POST times out after the request is sent" do
      stub_request(:post, sandbox_url("/orders")).to_raise(Net::ReadTimeout.new("read timeout"))

      expect { client.post("/orders", { order_amount: "10.00" }) }
        .to raise_error(CashfreePg::TimeoutError, /fetch before retrying/)

      expect(a_request(:post, sandbox_url("/orders"))).to have_been_made.once
    end

    it "raises APIError for a success response that is not JSON" do
      stub_request(:get, sandbox_url("/orders/x")).to_return(status: 200, body: "<html>")

      expect { client.get("/orders/x") }.to raise_error(CashfreePg::APIError, /invalid JSON/)
    end

    it "warns that a timed-out PATCH has an unknown outcome" do
      stub_request(:patch, sandbox_url("/orders/x")).to_raise(Net::ReadTimeout.new("read timeout"))

      expect { client.patch("/orders/x", { order_status: "TERMINATED" }) }
        .to raise_error(CashfreePg::TimeoutError, /fetch before retrying/)
    end

    it "raises ConnectionError when the host cannot be reached" do
      stub_request(:get, sandbox_url("/orders/x")).to_raise(Errno::ECONNREFUSED)

      expect { client.get("/orders/x") }.to raise_error(CashfreePg::ConnectionError)
      expect(a_request(:get, sandbox_url("/orders/x"))).to have_been_made.once
    end
  end

  it "rejects an absolute path" do
    expect { client.get("https://evil.test/orders") }.to raise_error(ArgumentError, /relative path/)
  end
end
