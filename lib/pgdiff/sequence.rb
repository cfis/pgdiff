module PgDiff
  class Sequence
    attr_accessor :schema, :name

    def self.compare(source, target, output)
      source.difference(target).each do |sequence|
        output << sequence.drop_statement << "\n"
      end

      target.difference(source).each do |sequence|
        output << sequence.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      query = <<~EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'S'
          #{ignore_schemas.empty? ? "" : "AND n.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1,2;
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(record['nspname'], record['relname'])
      end
    end

    def initialize(schema, name)
      @schema = schema
      @name = name
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

    def create_statement
      "CREATE SEQUENCE #{qualified_name};"
    end

    def drop_statement
      "DROP SEQUENCE #{qualified_name} CASCADE;"
    end
  end
end