module PgDiff
  class Schema
    attr_reader :name

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT nspname
        FROM pg_namespace
        WHERE nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).map do |hash|
        Schema.new(hash['nspname'])
      end
    end

    def initialize(name)
      @name = name
    end

    def eql?(other)
      self.name == other.name
    end

    def create_statement
      "CREATE SCHEMA #{name};"
    end

    def drop_statement
      "DROP SCHEMA #{name};"
    end
  end
end