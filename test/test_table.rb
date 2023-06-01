require File.expand_path('./test_helper', __dir__)

class TestTable < TestCase
  def test_load
    tables = PgDiff::Table.from_database(self.source_connection)
    assert_equal(6, tables.length)

    table_names = tables.map {|table| table.name}.sort
    assert_equal(["shared_table", "shared_table_attribute_order", "shared_table_attribute_types", "shared_table_constraints", "shared_table_indexes", "source_table"],
                 table_names)
  end

  def test_load_all
    tables = PgDiff::Table.from_database(self.source_connection, [])
    assert_equal(74, tables.length)
  end

  def test_compare
    source = PgDiff::Table.from_database(self.source_connection)
    target = PgDiff::Table.from_database(self.target_connection)

    output = StringIO.new
    PgDiff::Table.compare(source, target, output)
    expected = <<~EOS
      DROP TABLE public.source_table CASCADE;
      CREATE TABLE public.target_table
      (
        id integer NOT NULL,
        genus text NOT NULL,
        species text NOT NULL,
        PRIMARY KEY (id)
      );
      -- ==== public.shared_table_attribute_types =====
      -- Attributes --
      ALTER TABLE public.shared_table_attribute_types
      DROP COLUMN distance CASCADE;
      
      ALTER TABLE public.shared_table_attribute_types
      ADD COLUMN distance distance integer NOT NULL;


      -- ==== public.shared_table_attribute_order =====
      -- Attributes --
      ALTER TABLE public.shared_table_attribute_order
      DROP COLUMN distance CASCADE;
      
      ALTER TABLE public.shared_table_attribute_order
      ADD COLUMN distance distance integer NOT NULL;


      -- ==== public.shared_table_constraints =====
      -- Constraints --
      ALTER TABLE public.shared_table_constraints ADD CONSTRAINT shared_table_constraints_pkey
      PRIMARY KEY (id);

      -- ==== public.shared_table_indexes =====
      -- Indexes --
      DROP INDEX public.shared_table_indexes.street_idx;
      CREATE UNIQUE INDEX street_idx ON public.shared_table_indexes USING btree (street);

      DROP INDEX public.shared_table_indexes.code_idx;
      CREATE INDEX code_idx ON public.shared_table_indexes USING btree (code);
    EOS
    assert_equal(expected.strip, output.string.strip)
  end
end
