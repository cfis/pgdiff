module PgDiff
  class Domain
    attr_reader :oid, :schema, :name, :data_type, :not_null, :default, :collation, :constraints

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
        SELECT pg_type.oid,
               pg_namespace.nspname, 
               pg_type.typname, 
               pg_catalog.format_type(pg_type.typbasetype, pg_type.typtypmod) AS data_type,
               pg_type.typnotnull,
               pg_type.typdefault,
               collation_namespace.nspname AS collation_nspname,
               pg_collation.collname
        FROM pg_catalog.pg_type
        JOIN pg_catalog.pg_namespace ON pg_type.typnamespace = pg_namespace.oid
        LEFT OUTER JOIN pg_catalog.pg_collation ON pg_type.typcollation = pg_collation.oid		   
        LEFT OUTER JOIN pg_catalog.pg_namespace AS collation_namespace ON pg_collation.collnamespace = collation_namespace.oid
        WHERE pg_type.typtype = 'd'
          #{ignore_schemas.empty? ? "" : "AND pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY pg_namespace.nspname, pg_type.typname
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        collation = if record['collname']
                      Collation.new(record['collation_nspname'], record['collname'])
                    end

        set << new(connection, record['oid'], record['nspname'], record['typname'], record['data_type'],
                   record['typnotnull'], record['typdefault'], collation)
      end
    end

    def initialize(connection, oid, schema, name, data_type, not_null, default = nil, collation = nil, constraint_name = nil, checks = nil)
      @oid = oid
      @schema = schema
      @name = name
      @data_type = data_type
      @not_null = not_null
      @default = default
      @collation = collation
      @constraints = Constraints.from_database(connection, self)
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
      options = [self.collation ? "COLLATE #{self.collation.schema}.#{self.collation.name}" : nil,
                 self.not_null ? "NOT NULL" : "NULL",
                 self.default ? "DEFAULT #{self.default}" : nil]

      self.constraints.each do |name, constraint|
        if constraint.name
          options << "CONSTRAINT #{constraint.name} #{constraint.definition}"
        else
          options << constraint.definition
        end
      end

      statement = <<~EOT
        CREATE DOMAIN #{self.name} AS #{self.data_type}
        #{options.compact.join("\n")};
      EOT
      statement.strip
    end

    def drop_statement
      <<~EOT
        DROP DOMAIN #{qualified_name} CASCADE;
      EOT
    end
  end
end
