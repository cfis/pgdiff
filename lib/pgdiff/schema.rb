module PgDiff
  class Schema
    attr_reader :name

    def self.compare(source, target, output)
      output << "-- ==== Schemas ====" << "\n"
      source.difference(target).each do |schema|
        output << schema.drop_statement << "\n"
      end

      target.difference(source).each do |schema|
        output << schema.create_statement << "\n"
      end
      output << "\n"
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      where_clause = if ignore_schemas.empty?
                       ""
                     else
                       "WHERE nspname NOT IN (#{ignore_schemas.join(', ')})"
                     end

      query = <<~EOT
        SELECT nspname
        FROM pg_namespace
        #{where_clause}
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(record['nspname'])
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
