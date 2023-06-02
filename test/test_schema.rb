require File.expand_path('./test_helper', __dir__)

class TestSchema < TestCase
  def test_load
    schemas = PgDiff::Schema.from_database(self.source_connection)
    assert_equal(3, schemas.length)

    schema_names = schemas.map {|schema| schema.name}.sort
    assert_equal(["public", "shared_schema", "source_schema"],
                 schema_names)
  end

  def test_load_all
    schemas = PgDiff::Schema.from_database(self.source_connection, [])
    assert_equal(6, schemas.length)

    schema_names = schemas.map {|schema| schema.name}.sort
    assert_equal(["information_schema", "pg_catalog", "pg_toast", "public", "shared_schema", "source_schema"],
                 schema_names)
  end

  def test_compare
    source = PgDiff::Schema.from_database(self.source_connection)
    target = PgDiff::Schema.from_database(self.target_connection)

    output = StringIO.new
    PgDiff::Schema.compare(source, target, output)
    expected = <<~EOS
      -- ==== Schemas ====
      DROP SCHEMA source_schema;
      CREATE SCHEMA target_schema;
    EOS
    assert_equal(expected.strip, output.string.strip)
  end
end
