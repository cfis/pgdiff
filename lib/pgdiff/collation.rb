module PgDiff
  class Collation
    attr_accessor :schema, :name, :lc_collate, :ctype, :provider, :deterministic, :version

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      where_clause = if ignore_schemas.empty?
                       ""
                     else
                       "WHERE nspname NOT IN (#{ignore_schemas.join(', ')})"
                     end

      query = <<~EOT
        SELECT pg_collation.collname,
               pg_collation.collcollate,
               pg_collation.collctype,
               pg_collation.collprovider,
               pg_collation.collisdeterministic,
               pg_collation.collversion
        FROM pg_catalog.pg_collation
        JOIN pg_catalog.pg_namespace ON pg_collation.collnamespace = pg_namespace.oid
        #{where_clause}
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(record['nspname'], record['collname'], record['collprovider'], record['collisdeterministic'],
                   record['collcollate'], record['collctype'], record['collversion'])
      end
    end

    def initialize(schema, name, provider = nil, deterministic = nil, lc_collate = nil, ctype = nil, version = nil)
      @schema = schema
      @name = name
      @provider = provider
      @deterministic = deterministic
      @lc_collate = lc_collate
      @ctype = ctype
      @version = version
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
      options = {"LC_COLLATE" => @lc_collate,
                 "LC_CTYPE" => @ctype,
                 "PROVIDER" => @provider,
                 "DETERMINISTIC" => @deterministic,
                 "VERSION" => @version}.compact.map do |name, value|
        "#{name} = #{value}"
      end.join(", ")
      <<~EOT
        CREATE COLLATION #{qualified_name} 
        (
          #{options}
        );
      EOT
    end

    def drop_statement
      <<~EOT
        DROP COLLATION #{qualified_name} RESTRICT;
      EOT
    end
  end
end