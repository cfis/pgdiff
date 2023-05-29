module PgDiff
  class Domain
    attr_reader :schema, :name, :definition

    def self.compare(source, target, output)
      source.difference(target).each do |domain|
        output << domain.drop_statement << "\n"
      end

      target.difference(source).each do |domain|
        output << domain.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
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
          #{ignore_schemas.empty? ? "" : "AND n.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1, 2
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        set << new(record['nspname'], record['typname'], record['def'])
        set
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

    def hash
      self.qualified_name.hash
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
