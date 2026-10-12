# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe CashfreePg do
  # A fresh process catches missing requires that the test suite's own requires would hide.
  it "loads in a fresh process without warnings or Rails" do
    lib = File.expand_path("../lib", __dir__)
    script = 'require "cashfree_pg"; abort("Rails loaded") if defined?(Rails)'

    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-w", "-I", lib, "-e", script)

    expect(status).to be_success
    expect(stderr).to be_empty
  end
end
