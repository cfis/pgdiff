module PgDiff
  class Domain
    attr_reader :schema, :name, :definition

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT n.nspname, t.typname,  pg_catalog.format_type(t.typbasetype, t.typtypmod) || ' ' ||
           CASE WHEN t.typnotnull AND t.typdefault IS NOT NULL THEN 'not null default '|| t.typdefault
                WHEN t.typnotnull AND t.typdefault IS NULL THEN 'not null'
                WHEN NOT t.typnotnull AND t.typdefault IS NOT NULL THEN 'default '|| t.typdefault
                ELSE ''
           END AS def
        FROM pg_catalog.pg_type t
           LEFT JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace
        WHERE t.typtype = 'd'
          AND n.nspname NOT IN (#{ignore_schemas.join(', ')})
        ORDER BY 1, 2
      EOT

      connection.query(query).map do |record|
        Domain.new(record['nspname'], record['typname'], record['def'])
      end
    end

    def initialize(schema, name, definition)
      @schema = schema
      @name = name
      @definition = definition
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name
    end

    def drop_statement
      "DROP DOMAIN #{qualified_name} CASCADE;"
    end

    def create_statement
      <<~EOT
        CREATE DOMAIN #{name} AS
         #{definition};"
      EOT
    end
  end
end
