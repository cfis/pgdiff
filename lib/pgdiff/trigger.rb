module PgDiff
  class Trigger
    attr_reader :table_name, :name, :definition

    def initialize(table_name, name, df)
      @table_name = table_name
      @name = name
      @definition = df + ";"
    end

    def == (other)
      other.definition == definition
    end
  end
end