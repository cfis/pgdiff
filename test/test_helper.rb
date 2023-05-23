require 'bundler'
require 'minitest/autorun'

Bundler.setup(:default)
Bundler.require(:default)
require 'pgdiff'

module PgDiff
  CONNECTION_SPEC = {host: "localhost",
                     user: "postgres"}

  SOURCE_DATABASE = "pgdiff_source"
  TARGET_DATABASE = "pgdiff_target"
end

class TestCase < Minitest::Test
  def source_connection
    PG::Connection.new(PgDiff::CONNECTION_SPEC.merge(dbname: PgDiff::SOURCE_DATABASE))
  end

  def target_connection
    PG::Connection.new(PgDiff::CONNECTION_SPEC.merge(dbname: PgDiff::TARGET_DATABASE))
  end
end