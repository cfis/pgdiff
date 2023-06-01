module PgDiff
  class Indexes
    include Enumerable

    def self.compare(sources, targets, output)
      drops = []
      creates = []
      changes = []

      sources.each do |name, source|
        target = targets[name]
        case
          when target.nil?
            drops << source
          when !source.eql?(target)
            changes << [source, target]
        end
      end

      targets.each do |name, target|
        source = sources[name]
        if source.nil?
          creates << target
        end
      end

      drops.each do |index|
        output << index.drop_statement << "\n"
      end

      creates.each do |index|
        output << index.create_statement << "\n"
      end

      changes.each do |source, target|
        output << source.drop_statement << "\n"
        output << target.create_statement << "\n"
        output << "\n"
      end
    end

    def self.from_database(connection, table)
      # Find all non-primary key indices
      query  = <<~EOT
        SELECT pg_index.indexrelid::regclass AS name,
               pg_get_indexdef(pg_index.indexrelid) AS definition
        FROM pg_catalog.pg_index
        WHERE NOT indisprimary
              AND pg_index.indrelid = #{table.oid}
      EOT

      indexes = connection.query(query).each_with_object(Hash.new) do |record, hash|
        index = Index.new(record['name'], table, record['definition'])
        hash[index.name] = index
      end
      new(indexes)
    end

    def initialize(indexes)
      @indexes = indexes
    end

    def eql?(other)
      @indexes.eql?(other.instance_variable_get(:@indexes))
    end
    alias :== :eql?

    def each
      return enum_for(:each) unless block_given?

      @indexes.each do |index|
        yield index
      end

      self
    end

    def [](name)
      @indexes[name]
    end

    def definitions
      @indexes.map do |name, index|
        index.definition
      end
    end

    def definition
      definitions.join('\n')
    end
  end
end
