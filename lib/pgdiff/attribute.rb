module PgDiff
  class Attribute
    attr_accessor :table, :name, :type_def, :notnull, :default

    def initialize(table, name, typedef, notnull, default)
      @table = table
      @name = name
      @type_def = typedef
      @notnull = notnull
      @default = default
    end

    def eql?(other)
      self.table.qualified_name == other.table.qualified_name &&
        self.definition == other.definition
    end

    def hash
      "#{self.table.qualified_name}.#{self.name}".hash
    end

    def definition
      out = [@name,  @type_def]
      if @notnull
        out << 'NOT NULL'
      end
      if @default
        out << 'DEFAULT'
        out << @default
      end

      out.join(" ")
    end

    def to_s
      self.definition
    end
    alias :inspect :to_s
  end
end
