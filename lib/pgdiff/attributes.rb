require 'diff/lcs'
require 'diff/lcs/hunk'

module PgDiff
  class Attributes
    include Enumerable

    def self.compare(sources, targets, output)
      source_definitions = sources.definitions
      target_definitions = targets.definitions
      diffs = ::Diff::LCS.diff(source_definitions, target_definitions)

      file_length_difference = 0
      diffs.each do |piece|
        hunk = ::Diff::LCS::Hunk.new(source_definitions, target_definitions, piece, 0, file_length_difference)
        file_length_difference = hunk.file_length_difference
        output << hunk.diff(:unified).gsub(/^/, '   ') << "\n"
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

      attributes = connection.query(query).each_with_object(Array.new) do |record, array|
        array << Attribute.new(table, record['attname'], record['typedef'], record['attnotnull'], record['default'])
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
