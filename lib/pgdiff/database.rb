module PgDiff
  class Database
    attr_accessor :extensions, :tables, :views, :sequences, :schemas, :domains, :rules, :functions, :triggers

    def initialize(connection, ignore_schemas: [])
      # Combine ignore schemas and single quote them
      ignore_schemas += ['pg_catalog', 'pg_toast', 'information_schema']
      @ignore_schemas = ignore_schemas.map {|schema_name| "'#{schema_name}'"}

      load_schemas(connection)
      load_extensions(connection)
      load_domains(connection)
      load_tables(connection)
      load_views(connection)
      load_sequences(connection)
      load_functions(connection)
      load_rules(connection)
      load_triggers(connection)
    end

    def load_tables(connection)
      @tables = Table.from_database(connection, @ignore_schemas)
    end

    def load_views(connection)
      @views = View.from_database(connection, @ignore_schemas)
    end

    def load_sequences(connection)
      @sequences = Sequence.from_database(connection, @ignore_schemas)
    end

    def load_domains(connection)
      @domains = Domain.from_database(connection, @ignore_schemas)
    end

    def load_extensions(connection)
      @extensions = Extension.from_database(connection, @ignore_schemas)
    end

    def load_schemas(connection)
      @schemas = Schema.from_database(connection, @ignore_schemas)
    end

    def load_functions(connection)
      @functions = Function.from_database(connection, @ignore_schemas)
    end

    def load_rules(connection)
      @rules = Rule.from_database(connection, @ignore_schemas)
    end

    def load_triggers(connection)
      @triggers = Trigger.from_database(connection, @ignore_schemas)
    end
  end
end