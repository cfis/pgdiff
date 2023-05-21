module PgDiff
  class Schema
    attr_reader :name

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT nspname
        FROM pg_namespace
        WHERE nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).map do |record|
        new(record['nspname'])
      end
    end

    def initialize(name)
      @name = name
    end

    def eql?(other)
      self.name == other.name
    end

    def hash
      self.name.hash
    end

    def create_statement
      "CREATE SCHEMA #{name};"
    end

    def drop_statement
      "DROP SCHEMA #{name};"
    end
  end
end
