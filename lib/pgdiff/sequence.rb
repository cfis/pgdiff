module PgDiff
  class Sequence
    attr_accessor :schema, :name

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'S'
          AND n.nspname NOT IN (#{ignore_schemas.join(', ')})
        ORDER BY 1,2;
      EOT

      connection.query(query).map do |tuple|
        Sequence.new(tuple['nspname'], tuple['relname'])
      end
    end

    def initialize(schema, name)
      @schema = schema
      @name = name
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def definition
      "CREATE SEQUENCE #{@name} ;"
    end
  end
end