module PgDiff
  class Function
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

      connection.exec(query).map do |hash|
        Function.new(hash)
      end
    end

    def initialize(tuple)
      @name = tuple['namespace'] + "." + tuple['function_name']
      @language = tuple['language_name']
      @src = tuple['source_code']
      @returns_set = tuple['returns_set']
      @return_type = tuple['return_type']
      @arglist = tuple["function_arguments"]
      @strict = tuple['proisstrict'] ? ' STRICT' : ''
      @secdef = tuple['prosecdef'] ? ' SECURITY DEFINER' : ''
      @volatile = case tuple['provolatile']
        when 'i' then ' IMMUTABLE'
        when 's' then ' STABLE'
        else ''
      end
    end

    def signature
      "#{@name}(#{@arglist})"
    end

    def definition
      <<~EOT
        CREATE OR REPLACE FUNCTION #{@name} (#{@arglist}) RETURNS #{@returns_set ? 'SETOF' : ''} #{@return_type} AS $_$#{@src}$_$ LANGUAGE '#{@language}' #{@volatile}#{@strict}#{@secdef};
      EOT
    end

    def == (other)
      definition == other.definition
    end
  end
end