module PgDiff
  class Attributes
    include Enumerable

    def self.compare(source, target, output)
      source.difference(target).each do |domain|
        output << domain.drop_statement << "\n"
      end

      target.difference(source).each do |domain|
        output << domain.create_statement << "\n"
      end
    end

    def self.from_database(connection, table)
      query  = <<~EOT
        SELECT attname, 
               format_type(atttypid, atttypmod) AS typedef, 
               attnotnull, 
               pg_get_expr(adbin, attrelid) AS default
        FROM pg_attribute
        LEFT JOIN  pg_attrdef ON (adrelid = attrelid AND adnum = attnum)
        WHERE attrelid = '#{table.oid}'::regclass 
          AND NOT attisdropped and attnum > 0
        ORDER BY attnum;
      EOT

      attributes = connection.query(query).reduce(Array.new) do |array, record|
        array << Attribute.new(table, record['attname'], record['typedef'], record['attnotnull'], record['default'])
        array
      end

      new(attributes)
    end

    def initialize(attributes)
      @attributes = attributes
    end

    def each
      return enum_for(:each) unless block_given?

      @attributes.each do |attribute|
        yield attribute
      end

      self
    end

    def eql?(other)
      @attributes.eql?(other.instance_variable_get(:@attributes))
    end
    alias :== :eql?

    def definitions
      @attributes.map do |attribute|
        attribute.definition
      end
    end

    def definition
      definitions.join('\n')
    end

    def include?(name)
      @attributes.find do |attribute|
        attribute.name == name
      end
    end

    def index(name)
      @attributes.find_index do |attribute|
        attribute.name == name
      end
    end
  end
end
