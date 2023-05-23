module PgDiff
  class View
    attr_reader :schema, :name, :definition

    def self.compare(source, target, output)
      source.difference(target).each do |view|
        output << view.drop_statement << "\n"
      end

      target.difference(source).each do |view|
        output << view.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas = [])
      query  = <<~EOT
        SELECT n.nspname, c.oid, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'v'
          #{ignore_schemas.empty? ? "" : "AND n.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1,2;
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        oid = record['oid']
        schema = record['nspname']
        name = record['relname']
        view_query = <<~EOT
          SELECT pg_catalog.pg_get_viewdef(#{oid}, true)
        EOT
        definition = connection.query(view_query).first['pg_get_viewdef']
        set << new(schema, name, definition)
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
      <<~EOT
        CREATE VIEW #{qualified_name} AS
        #{definition}
      EOT
    end

    def drop_statement
      "DROP VIEW #{qualified_name};"
    end
  end
end