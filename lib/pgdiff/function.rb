module PgDiff
  class Function
    def initialize(conn, tuple)
      @name = tuple['namespace'] + "." + tuple['function_name']
      @language = tuple['language_name']
      @src = tuple['source_code']
      @returns_set = tuple['returns_set']
      @return_type = format_type(conn, tuple['return_type'])
      @tipes = tuple['function_args'].split(" ")
      if tuple['function_arg_names'] && tuple['function_arg_names'] =~ /^\{(.*)\}$/
        @arnames = $1.split(',')
      elsif tuple['function_arg_names'].is_a? Array # my version of ruby-postgres
        @arnames = tuple['function_arg_names']
      else
        @arnames = [""] * @tipes.length
      end
      alist = []
      @tipes.each_with_index do |typ,idx|
        alist << (@arnames[idx] + " " + format_type(conn, typ))
      end
      @arglist = alist.join(" , ")
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
      <<-EOT
  CREATE OR REPLACE FUNCTION #{@name} (#{@arglist}) RETURNS #{@returns_set ? 'SETOF' : ''} #{@return_type} AS $_$#{@src}$_$ LANGUAGE '#{@language}' #{@volatile}#{@strict}#{@secdef};
  EOT
    end

    def == (other)
      definition == other.definition
    end

    def format_type(conn, oid)
      t_query = <<-EOT
      SELECT pg_catalog.format_type(pg_type.oid, typtypmod) AS type_name
       FROM pg_catalog.pg_type
       JOIN pg_catalog.pg_namespace ON (pg_namespace.oid = typnamespace)
       WHERE pg_type.oid =
      EOT
      tuple = conn.query(t_query + oid.to_s).first
      tuple['type_name']
    end
  end
end