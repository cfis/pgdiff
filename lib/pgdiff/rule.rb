module PgDiff
  class Rule
    attr_reader :name, :name, :definition

    def self.compare(source, target, output)
      source.difference(target).each do |rules|
        output << rules.drop_statement << "\n"
      end

      target.difference(source).each do |rules|
        output << rules.create_statement << "\n"
      end
    end
    
    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT  schemaname || '.' ||  tablename || '.' || rulename AS rule_name,
                schemaname || '.' ||  tablename AS tab_name,
                definition
        FROM pg_rules
        WHERE schemaname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        set << new(record['tab_name'], record['rule_name'], record['definition'])
        set
      end
    end

    def initialize(table_name, name, df)
      @table_name = table_name
      @name = name
      @definition = df
    end

    def eql?(other)
      self.definition == other.definition
    end

    def hash
      self.definition.hash
    end

    def create_statement
      definition
    end

    def drop_statement
      "DROP RULE #{rule.name} ON #{rule.table_name} CASCADE;"
    end
  end
end
