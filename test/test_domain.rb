require File.expand_path('./test_helper', __dir__)

class TestDomain < TestCase
  def test_load
    domains = PgDiff::Domain.from_database(self.source_connection)
    assert_equal(2, domains.length)

    domains = domains.to_a

    domain = domains[0]
    assert_equal("public", domain.schema)
    assert_equal("shared_domain", domain.name)

    domain = domains[1]
    assert_equal("public", domain.schema)
    assert_equal("source_domain", domain.name)
  end

  def test_load_all
    domains = PgDiff::Domain.from_database(self.source_connection, [])
    assert_equal(7, domains.length)

    domains = domains.to_a

    domain = domains[0]
    assert_equal("information_schema", domain.schema)
    assert_equal("cardinal_number", domain.name)
  end

  def test_compare
    source = PgDiff::Domain.from_database(self.source_connection)
    target = PgDiff::Domain.from_database(self.target_connection)

    output = StringIO.new
    PgDiff::Domain.compare(source, target, output)
    expected = <<~EOS
      -- ==== Domains ====
      DROP DOMAIN public.source_domain CASCADE;
      
      CREATE DOMAIN target_domain AS text
      COLLATE pg_catalog.default
      NOT NULL
      CONSTRAINT target_domain_check CHECK (((VALUE ~ '^\\d{5}$'::text) OR (VALUE ~ '^\\d{5}-\\d{4}$'::text)))
      CONSTRAINT length CHECK ((length(VALUE) <= 10));
    EOS
    assert_equal(expected.strip, output.string.strip)
  end
end
