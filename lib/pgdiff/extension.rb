module PgDiff
  class Extension
    attr_reader :schema, :name, :version

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT *
        FROM pg_catalog.pg_extension
        JOIN pg_namespace ON pg_extension.extnamespace = pg_namespace.oid
        WHERE pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).map do |hash|
        Extension.new(hash['nspname'], hash['extname'], hash['extversion'])
      end
    end

    def initialize(schema, name, version)
      @schema = schema
      @name = name
      @version = version
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def equal?(other)
      self.qualified_name == other.qualified_name &&
        self.version == other.version
    end

    def create_statement
      "CREATE EXTENSION #{name} WITH SCHEMA #{schema} VERSION #{version};"
    end

    def drop_statement
      "DROP EXTENSION #{qualified_name};"
    end
  end
end
