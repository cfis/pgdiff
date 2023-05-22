module PgDiff
  class Extension
    attr_reader :schema, :name, :version

    def self.compare(source, target, output)
      source.intersection(target).each do |old_extension|
        new_extension = target.find do |an_extension|
          old_extension.qualified_name == an_extension.qualified_name
        end
        if old_extension.version < new_extension.version
          # Upgrade
          output << new_extension.alter_statement << "\n"
        elsif old_extension.version > new_extension.version
          # Downgrade
          output << old_extension.drop_statement << "\n"
          output << new_extension.create_statement << "\n"
        end
      end

      source.difference(target).each do |extension|
        output << extension.drop_statement << "\n"
      end

      target.difference(source).each do |extension|
        output << extension.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT *
        FROM pg_catalog.pg_extension
        JOIN pg_namespace ON pg_extension.extnamespace = pg_namespace.oid
        WHERE pg_namespace.nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        set << new(record['nspname'], record['extname'], record['extversion'])
        set
      end
    end

    def initialize(schema, name, version)
      @schema = schema
      @name = name
      @version = Gem::Version.new(version)
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
      "CREATE EXTENSION #{name} WITH SCHEMA #{schema} VERSION #{version};"
    end

    def drop_statement
      "DROP EXTENSION #{qualified_name}; -- Version #{version}"
    end

    def alter_statement
      "ALTER EXTENSION #{qualified_name} UPDATE TO #{version};"
    end
  end
end
