module PgDiff
  class Constraint
    attr_accessor :table, :name, :definition

    def initialize(table, name, definition)
      @table = table
      @name = name
      @definition = definition
    end

    def eql?(other)
      self.table.qualified_name == other.table.qualified_name &&
        self.definition == other.definition
    end

    def hash
      "#{self.table.qualified_name}.#{self.name}".hash
    end

    def create_statement
      <<~EOT
        ALTER TABLE #{self.table.qualified_name} ADD CONSTRAINT #{@name}
        #{@definition};
      EOT
    end

    def drop_statement
      <<~EOT
        ALTER TABLE #{self.table.qualified_name} DROP CONSTRAINT #{@name};"
      EOT
    end

    def to_s
      self.definition
    end
    alias :inspect :to_s
  end
end
