module PgDiff
  class Constraint
    attr_accessor :table_or_domain, :name, :definition

    def initialize(table_or_domain, name, definition)
      @table_or_domain = table_or_domain
      @name = name
      @definition = definition
    end

    def eql?(other)
      self.table_or_domain.qualified_name == other.table_or_domain.qualified_name &&
        self.definition == other.definition
    end

    def hash
      "#{self.table_or_domain.qualified_name}.#{self.name}".hash
    end

    def create_statement
      <<~EOT
        ALTER TABLE #{self.table_or_domain.qualified_name} ADD CONSTRAINT #{@name}
        #{@definition};
      EOT
    end

    def drop_statement
      <<~EOT
        ALTER TABLE #{self.table_or_domain.qualified_name} DROP CONSTRAINT #{@name};"
      EOT
    end

    def to_s
      self.definition
    end
    alias :inspect :to_s
  end
end
