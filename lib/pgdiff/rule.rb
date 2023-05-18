module PgDiff
  class Rule
    attr_reader :name, :name, :definition

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT  schemaname || '.' ||  tablename || '.' || rulename AS rule_name,
                schemaname || '.' ||  tablename AS tab_name,
                definition
        FROM pg_rules
        WHERE schemaname NOT IN (#{ignore_schemas.join(', ')})
      EOT

      connection.exec(query).map do |hash|
        Rule.new(hash['tab_name'], hash['rule_name'], hash['definition'])
      end
    end

    def initialize(table_name, name, df)
      @table_name = table_name
      @name = name
      @definition = df
    end

    def == (other)
      other.definition == definition
    end
  end
end
