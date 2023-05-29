require File.expand_path('./test_helper', __dir__)

class TestTable < TestCase
  def test_load
    tables = PgDiff::Table.from_database(self.source_connection)
    assert_equal(5, tables.length)

    table_names = tables.map {|table| table.name}.sort
    assert_equal(["shared_table", "shared_table_attribute_order", "shared_table_attribute_types", "shared_table_constraints", "source_table"],
                 table_names)
  end

  def test_load_all
    tables = PgDiff::Table.from_database(self.source_connection, [])
    assert_equal(73, tables.length)
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
      /* Table public.shared_table_attribute_types has changed attributes
         @@ -3 +3 @@
         -distance double precision NOT NULL
         +distance integer NOT NULL
      */
      DROP TABLE public.shared_table_attribute_types CASCADE;
      CREATE TABLE public.shared_table_attribute_types
      (
        id integer NOT NULL,
        name text NOT NULL,
        distance integer NOT NULL,
        start_location text NOT NULL,
        finish_location text NOT NULL,
        PRIMARY KEY (id)
      );

      /* Table public.shared_table_attribute_order has changed attributes
         @@ -3 +2 @@
         -distance double precision NOT NULL
         @@ -5 +5 @@
         +distance integer NOT NULL
      */
      DROP TABLE public.shared_table_attribute_order CASCADE;
      CREATE TABLE public.shared_table_attribute_order
      (
        id integer NOT NULL,
        name text NOT NULL,
        start_location text NOT NULL,
        finish_location text NOT NULL,
        distance integer NOT NULL,
        PRIMARY KEY (id)
      );

      ALTER TABLE public.shared_table_constraints ADD CONSTRAINT shared_table_constraints_pkey
      PRIMARY KEY (id);
    EOS
    assert_equal(expected.strip, output.string.strip)
  end
end
