module PgDiff
  class Index
    attr_reader :name, :table, :definition

    def initialize(name, table, definition)
      @name = name
      @table = table
      @definition = definition
    end

    def qualified_name
      "#{self.table.qualified_name}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name &&
        self.definition == other.definition
    end

    def hash
      self.qualified_name.hash
    end

    def create_statement
      "#{self.definition};"
    end

    def drop_statement
      "DROP INDEX #{qualified_name};"
    end
  end
end