module PgDiff
  class Trigger
    attr_reader :name, :name, :definition

    def self.compare(source, target, output)
      source.difference(target).each do |trigger|
        output << trigger.drop_statement << "\n"
      end

      target.difference(source).each do |trigger|
        output << trigger.create_statement << "\n"
      end
    end

    def self.from_database(connection, ignore_schemas = Database::SYSTEM_SCHEMAS)
      query =  <<~EOT
        SELECT nspname || '.' || relname as tgtable, tgname, pg_get_triggerdef(pg_trigger.oid) as tg_def
        FROM pg_trigger
        JOIN pg_class ON pg_trigger.tgrelid = pg_class.oid
        JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
        WHERE NOT tgisinternal
          AND nspname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).each_with_object(Set.new) do |record, set|
        set << new(record['tgtable'], record['tgname'], record['tg_def'])
      end
    end

    def initialize(table_name, name, df)
      @table_name = table_name
      @name = name
      @definition = df + ";"
    end

    def eql?(other)
      self.definition == other.definition
    end

    def hash
      self.definition.hash
    end

    def create_statement
      self.definition
    end

    def drop_statement
      "DROP trigger #{trigger.name} ON #{trigger.table_name} CASCADE;"
    end
  end
end