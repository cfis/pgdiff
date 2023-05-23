module PgDiff
  class Table
    attr_accessor :schema, :name, :attributes, :constraints, :indexes

    def self.compare(source, target, output)
      # --- Tables ----
      source.difference(target).each do |table|
        output << table.drop_statement << "\n"
      end

      target.difference(source).each do |table|
        output << table.create_statement << "\n"
      end

      # --- Indexes ----


      # @to_compare = []
      # @new_database.tables.each do |name, table|
      #   unless @old_database.tables.has_key?(name)
      #     add_script(:tables_create ,  table.create_statement)
      #     add_script(:indices_create ,  table.index_creation) unless table.indexes.empty?
      #     @to_compare << name
      #   else
      #     diff_attributes(@old_database.tables[name], table)
      #     diff_indexes(@old_database.tables[name], table)
      #     @to_compare << name
      #   end
      # end
    end

    def compare_table_constraints
      @c_check = []
      @c_primary = []
      @c_unique = []
      @c_foreign = []
      @to_compare.each do |name|
        if @old_database.tables[name]
          diff_constraints(@old_database.tables[name], @new_database.tables[name])
        else
          @new_database.tables[name].constraints.each do |cname, cdef|
            add_cnstr(name,  cname, cdef)
          end
        end
      end
      @script[:constraints_create] += @c_check
      @script[:constraints_create] += @c_primary
      @script[:constraints_create] += @c_unique
      @script[:constraints_create] += @c_foreign
    end

    def self.from_database(connection, ignore_schemas = [])
      query = <<~EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r'
          #{ignore_schemas.empty? ? "" : "AND n.nspname NOT IN (#{ignore_schemas.join(', ')})"}
        ORDER BY 1,2;
      EOT

      connection.query(query).reduce(Set.new) do |set, record|
        set << new(connection, record['nspname'], record['relname'])
        set
      end
    end
    
    def initialize(connection, schema, table_name)
      @schema = schema
      @name = table_name
      @attributes = {}
      @constraints = {}
      @indexes = Index.from_database(connection, self)
      @atlist = []

      # att_query = <<~EOT
      #   select attname, format_type(atttypid, atttypmod) as a_type, attnotnull,  pg_get_expr(adbin, attrelid) as a_default
      #   from pg_attribute left join pg_attrdef  on (adrelid = attrelid and adnum = attnum)
      #   where attrelid = '#{schema}.#{table_name}'::regclass and not attisdropped and attnum > 0
      #   order by attnum
      # EOT
      #
      # connection.query(att_query).each do |tuple|
      #   attname = tuple['attname']
      #   typedef = tuple['a_type']
      #   notnull = tuple['attnotnull']
      #   default = tuple['a_default']
      #   @attributes[attname] = Attribute.new(attname, typedef, notnull, default)
      #   @atlist << attname
      # end
      #
      # cons_query = <<~EOT
      #   select conname, pg_get_constraintdef(oid) from pg_constraint where conrelid = '#{schema}.#{table_name}'::regclass
      # EOT
      #
      # connection.query(cons_query).each do |tuple|
      #   name = tuple['conname']
      #   value = tuple['pg_get_constraintdef']
      #   @constraints[name] = value
      # end
      #
      # @constraints.keys.each do |cname|
      #   @indexes.delete("#{schema}.#{cname}") if has_index?(cname)
      # end
    end

    def qualified_name
      "#{self.schema}.#{self.name}"
    end

    def eql?(other)
      self.qualified_name == other.qualified_name
    end

    def hash
      self.qualified_name.hash
    end

    def has_attribute?(name)
      @attributes.has_key?(name)
    end

    def attribute_index(name)
      @atlist.index(name)
    end

    def has_index?(name)
      @indexes.has_key?(name) || @indexes.has_key?("#{schema}.#{name}")
    end

    def has_constraint?(name)
      @constraints.has_key?(name)
    end

    def table_creation
      out = ["CREATE TABLE #{qualified_name} ("]
      stmt = []
      @atlist.each do |attname|
        stmt << @attributes[attname].definition
      end
      out << stmt.join(",\n")
      out << ");"
      out.join("\n")
    end

    def index_creation
      out = []
      @indexes.values.each do |c|
        out << (c+";")
      end
      out.join("\n")
    end

    def create_statement
      self.table_creation
    end

    def drop_statement
      "DROP TABLE #{qualified_name} CASCADE;"
    end
  end
end