require 'bundler'
require 'minitest/autorun'

Bundler.setup(:default)
Bundler.require(:default)

require 'pgdiff'
require_relative './connection_spec'

class TestCase < Minitest::Test
  def source_connection
    PG::Connection.new(PgDiff::ConnectionSpec.source)
  end

  def target_connection
    PG::Connection.new(PgDiff::ConnectionSpec.target)
  end
end