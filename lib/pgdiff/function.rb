module PgDiff
  class Function
    def initialize(conn, tuple)
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

    def format_type(conn, oid)
      type_query = <<~EOT
        SELECT pg_catalog.format_type(pg_type.oid, typtypmod) AS type_name
        FROM pg_catalog.pg_type
        JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = typnamespace)
        WHERE pg_type.oid = #{oid}
      EOT
      tuple = conn.query(type_query).first
      tuple['type_name']
    end
  end
end