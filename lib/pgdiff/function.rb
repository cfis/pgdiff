module PgDiff
  class Function
    attr_reader :schema, :name, :arguments, :source

    def self.compare(source, target, output)
      source.difference(target).each do |function|
        output << function.drop_statement << "\n"
      end

      target.difference(source).each do |function|
        output << function.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      query = <<~EOT
       SELECT nspname AS namespace,
              proname AS function_name,
              pg_extension.extname AS extension_name,
              pg_get_function_arguments(pg_proc.oid) AS function_arguments,
              proretset AS returns_set,
              pg_catalog.format_type(prorettype, pg_type.typtypmod) AS return_type,
              prosrc AS source_code,
              lanname AS language_name,
              provolatile,
              proisstrict,
              prosecdef
       FROM pg_catalog.pg_proc
       JOIN pg_catalog.pg_language ON (pg_language.oid = prolang)
       JOIN pg_catalog.pg_namespace ON (pronamespace = pg_namespace.oid)
       JOIN pg_catalog.pg_type ON (prorettype = pg_type.oid)
       LEFT OUTER JOIN pg_catalog.pg_depend ON (pg_proc.oid = pg_depend.objid AND deptype = 'e')
       LEFT OUTER JOIN pg_catalog.pg_extension ON (pg_depend.refobjid = pg_extension.oid)
       WHERE pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})
         AND proname != 'plpgsql_call_handler'
         AND proname != 'plpgsql_validator'
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(record['namespace'],
                   record['function_name'],
                   extension: record["extension_name"],
                   arguments: record["function_arguments"],
                   returns_set: record['returns_set'],
                   return_type: record['return_type'],
                   source: record['source_code'],
                   language: record['language_name'],
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
                   extension:, arguments:, language:, source:, returns_set:, return_type:,
                   strict:, secdef:, volatile:)
      @schema = schema
      @name = name
      @extension = extension
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
      result = <<~EOT
        #{@extension ? '-- Extension: ' + @extension : ''}
        CREATE OR REPLACE FUNCTION #{qualified_name}(#{arguments})
        RETURNS #{@returns_set ? 'SETOF' : ''} #{@return_type} AS $$
        #{@source.strip}
        $$ LANGUAGE '#{@language}' #{[@volatile, @strict, @secdef].compact.join(" ")};
      EOT
      result.lstrip
    end

    def drop_statement
      "DROP FUNCTION #{qualified_name} CASCADE;#{@extension ? ' -- Extension: ' + @extension : ''}"
    end
  end
end