module PgDiff
  class Table
    attr_accessor :schema, :name, :attributes, :constraints, :indexes

    def self.from_database(connection, ignore_schemas)
      query = <<~EOT
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_catalog.pg_class c
        LEFT JOIN pg_catalog.pg_user u ON u.usesysid = c.relowner
        LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'r'
          AND n.nspname NOT IN (#{ignore_schemas.join(', ')})
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
      @indexes = {}
      @atlist = []

      att_query = <<~EOT
        select attname, format_type(atttypid, atttypmod) as a_type, attnotnull,  pg_get_expr(adbin, attrelid) as a_default
        from pg_attribute left join pg_attrdef  on (adrelid = attrelid and adnum = attnum)
        where attrelid = '#{schema}.#{table_name}'::regclass and not attisdropped and attnum > 0
        order by attnum
      EOT

      connection.query(att_query).each do |tuple|
        attname = tuple['attname']
        typedef = tuple['a_type']
        notnull = tuple['attnotnull']
        default = tuple['a_default']
        @attributes[attname] = Attribute.new(attname, typedef, notnull, default)
        @atlist << attname
      end

      ind_query = <<~EOT
        select indexrelid::regclass as indname, pg_get_indexdef(indexrelid) as def
        from pg_index where indrelid = '#{schema}.#{table_name}'::regclass and not indisprimary
      EOT

      connection.query(ind_query).each do |tuple|
        name = tuple['indname']
        value = tuple['def']
        @indexes[name] = value
      end

      cons_query = <<~EOT
        select conname, pg_get_constraintdef(oid) from pg_constraint where conrelid = '#{schema}.#{table_name}'::regclass
      EOT

      connection.query(cons_query).each do |tuple|
        name = tuple['conname']
        value = tuple['pg_get_constraintdef']
        @constraints[name] = value
      end

      @constraints.keys.each do |cname|
        @indexes.delete("#{schema}.#{cname}") if has_index?(cname)
      end
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