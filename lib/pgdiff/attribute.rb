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

      # def diff_attributes(old_table, new_table)
      #   dropped = []
      #   added   = []
      #   changed = []
      #
      #   order = []
      #   old_table.attributes.keys.each do |attname|
      #     if new_table.has_attribute?(attname)
      #       changed << attname if old_table.attributes[attname] != new_table.attributes[attname]
      #     else
      #       dropped << attname
      #     end
      #   end
      #
      #   old_table.attributes.keys.each do |attname|
      #     if new_table.has_attribute?(attname)
      #       old_index = old_table.attribute_index(attname)
      #       new_index = new_table.attribute_index(attname)
      #       order << attname if old_index != new_index
      #     end
      #   end
      #   new_table.attributes.keys.each do |attname|
      #     added << attname unless old_table.has_attribute?(attname)
      #   end
      #   add_script(:tables_change ,  "--  [#{old_table.name}] dropped attributes") unless dropped.empty?
      #   dropped.each do |attname|
      #     add_script(:tables_change ,  "ALTER TABLE #{old_table.name} DROP COLUMN #{attname} CASCADE;")
      #   end
      #   add_script(:tables_change ,  "--  [#{old_table.name}] added attributes") unless added.empty?
      #   added.each do |attname|
      #     add_script(:tables_change ,  "    ALTER TABLE #{old_table.name} ADD COLUMN #{new_table.attributes[attname].definition};")
      #   end
      #   add_script(:tables_change ,  "--  [#{old_table.name}] changed attributes") unless changed.empty?
      #   changed.each do |attname|
      #     old_att = old_table.attributes[attname]
      #     new_att = new_table.attributes[attname]
      #     add_script(:tables_change ,  "--   attribute: #{attname}")
      #     add_script(:tables_change ,  "--     OLD : #{old_att.definition}")
      #     add_script(:tables_change ,  "--     NEW : #{new_att.definition}")
      #     if old_att.type_def != new_att.type_def
      #       add_script(:tables_change ,  "      ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} TYPE #{new_att.type_def};")
      #     end
      #     if old_att.default != new_att.default
      #       if new_att.default.nil?
      #         add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} DROP DEFAULT;")
      #       else
      #         add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} SET DEFAULT #{new_att.default};")
      #       end
      #     end
      #     if old_att.notnull != new_att.notnull
      #       add_script(:tables_change ,  "       ALTER TABLE #{old_table.name} ALTER COLUMN #{attname} #{new_att.notnull ? 'SET' : 'DROP'} NOT NULL;")
      #     end
      #   end
      #
      #   add_script(:tables_change ,   "--  [#{old_table.name}] attribute order changed") unless order.empty?
      #   order.each do |attname|
      #     add_script(:tables_change , "--    #{attname}.  Old index: #{old_table.attribute_index(attname)}, New index: #{new_table.attribute_index(attname)}")
      #   end
      # end
    end

    def to_s
      self.name
    end
    alias :inspect :to_s
  end
end
