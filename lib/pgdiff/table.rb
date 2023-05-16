module PgDiff
  class Table
    attr_accessor :table_name, :schema, :attributes, :constraints, :indexes

    def initialize(conn, schema, table_name)
      @schema = schema
      @table_name = table_name
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
      conn.query(att_query).each do |tuple|
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
      conn.query(ind_query).each do |tuple|
        name = tuple['indname']
        value = tuple['def']
        @indexes[name] = value
      end

      cons_query = <<~EOT
        select conname, pg_get_constraintdef(oid) from pg_constraint where conrelid = '#{schema}.#{table_name}'::regclass
      EOT
      conn.query(cons_query).each do |tuple|
        name = tuple['conname']
        value = tuple['pg_get_constraintdef']
        @constraints[name] = value
      end
      @constraints.keys.each do |cname|
        @indexes.delete("#{schema}.#{cname}") if has_index?(cname)
      end
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
      out = ["CREATE TABLE #{name} ("]
      stmt = []
      @atlist.each do |attname|
        stmt << @attributes[attname].definition
      end
      out << stmt.join(",\n")
      out << ");"
      out.join("\n")
    end

    def name
      "#{schema}.#{table_name}"
    end

    def index_creation
      out = []
      @indexes.values.each do |c|
        out << (c+";")
      end
      out.join("\n")
    end
  end
end