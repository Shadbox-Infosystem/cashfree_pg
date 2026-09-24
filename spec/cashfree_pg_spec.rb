# frozen_string_literal: true

RSpec.describe CashfreePg do
  it "has a version number" do
    expect(CashfreePg::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end
end
