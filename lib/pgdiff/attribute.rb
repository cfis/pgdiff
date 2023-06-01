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

    def create_statement
      <<~EOT
        ALTER TABLE #{self.table.qualified_name}
        ADD COLUMN #{self.name} #{self.definition};
      EOT
    end

    def drop_statement
      <<~EOT
        ALTER TABLE #{self.table.qualified_name}
        DROP COLUMN #{self.name} CASCADE;
      EOT
    end

    def update_statement(other, output)
      if self.type_def != other.type_def
        output << "ALTER TABLE #{self.table.qualified_name}" << "\n" <<
                  "ALTER COLUMN #{self.name} TYPE #{output.type_def};"
      end

      if self.default != other.default
        if other.default.nil?
          output << "ALTER TABLE #{self.table.qualified_name}" << "\n" <<
                    "ALTER COLUMN #{self.name} DROP DEFAULT;"
        else
          output << "ALTER TABLE #{self.table.qualified_name}" << "\n" <<
                    "ALTER COLUMN #{self.name} SET DEFAULT #{self.default};"
        end
      end

      if self.notnull != other.notnull
        if other.default.nil?
          output << "ALTER TABLE #{self.table.qualified_name}" << "\n" <<
            "ALTER COLUMN #{self.name} DROP NOT NULL;"
        else
          output << "ALTER TABLE #{self.table.qualified_name}" << "\n" <<
            "ALTER COLUMN #{self.name} SET NOT NULL"
        end
      end
    end

    def to_s
      self.name
    end
    alias :inspect :to_s
  end
end
