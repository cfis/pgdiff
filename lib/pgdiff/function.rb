module PgDiff
  class Function
    attr_reader :schema, :name, :arguments, :source

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
       SELECT proname AS function_name,
         nspname AS namespace,
         lanname AS language_name,
         pg_catalog.obj_description(pg_proc.oid, 'pg_proc') AS comment,
         pg_get_function_arguments(pg_proc.oid) AS function_arguments,
         prosrc AS source_code,
         proretset AS returns_set,
         pg_catalog.format_type(prorettype, pg_type.typtypmod) AS return_type,
         provolatile,
         proisstrict,
         prosecdef
       FROM pg_catalog.pg_proc
       JOIN pg_catalog.pg_language ON (pg_language.oid = prolang)
       JOIN pg_catalog.pg_namespace ON (pronamespace = pg_namespace.oid)
       JOIN pg_catalog.pg_type ON (prorettype = pg_type.oid)
       WHERE pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})
         AND proname != 'plpgsql_call_handler'
         AND proname != 'plpgsql_validator'
      EOT

      connection.exec(query).map do |record|
        new(record['namespace'], record['function_name'],
            arguments: record["function_arguments"],
            language: record['language_name'],
            source: record['source_code'],
            returns_set: record['returns_set'],
            return_type: record['return_type'],
            strict: record['proisstrict'] ? 'STRICT' : nil,
            secdef: record['prosecdef'] ? 'SECURITY DEFINER' : nil,
            volatile: case record['provolatile']
                        when 'i' then 'IMMUTABLE'
                        when 's' then 'STABLE'
                        else nil
                      end)
      end
    end

    def initialize(schema, name,
                   arguments:, language:, source:, returns_set:, return_type:,
                   strict:, secdef:, volatile:)
      @schema = schema
      @name = name
      @arguments = arguments
      @language = language
      @source = source
      @returns_set = returns_set
      @return_type = return_type
      @strict = strict
      @secdef = secdef
      @volatile = volatile
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.signature == other.signature &&
        self.source == other.source
    end

    def hash
      self.qualified_name.hash
    end

    def signature
      "#{qualified_name}(#{arguments})"
    end

    def create_statement
      <<~EOT
        CREATE OR REPLACE FUNCTION #{qualified_name}(#{arguments})
        RETURNS #{@returns_set ? 'SETOF' : ''} #{@return_type} AS $$
        #{@source}
        $$ LANGUAGE '#{@language}' #{[@volatile, @strict, @secdef].compact.join(" ")};
      EOT
    end

    def drop_statement
      "DROP FUNCTION #{qualified_name} CASCADE;"
    end
  end
end