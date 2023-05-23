module PgDiff
  class Index
    attr_reader :schema, :name, :definition

    def self.compare(source, target, output)
      source.difference(target).each do |index|
        output << index.drop_statement << "\n"
      end

      target.difference(source).each do |index|
        output << index.create_statement << "\n"
      end
    end

    def self.from_database(connection, table)
      query  = <<~EOT
        SELECT indexrelid::regclass AS indname,
               pg_get_indexdef(indexrelid) AS def
        FROM pg_index
        WHERE indrelid = '#{table.qualified_name}'::regclass 
          AND NOT indisprimary
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        new(table.schema, record['indname'], record['def'])
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
      self.qualified_name == other.qualified_name &&
        self.definition == other.definition
    end

    def hash
      self.qualified_name.hash
    end

    def create_statement
      self.definition
    end

    def drop_statement
      "DROP INDEX #{qualified_name};"
    end
  end
end