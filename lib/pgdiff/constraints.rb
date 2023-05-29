module PgDiff
  class Constraints
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

      drops.each do |constraint|
        output << constraint.drop_statement << "\n"
      end

      creates.each do |constraint|
        output << constraint.create_statement << "\n"
      end

      changes.each do |source, target|
        output << source.drop_statement << "\n"
        output << target.create_statement << "\n"
      end
    end

    def self.from_database(connection, table)
      query  = <<~EOT
        SELECT conname,
               pg_get_constraintdef(oid) 
        FROM pg_constraint
        WHERE conrelid = #{table.oid}
      EOT

      constraints = connection.query(query).each_with_object(Hash.new) do |record, hash|
        constraint = Constraint.new(table, record['conname'], record['pg_get_constraintdef'])
        hash[constraint.name] = constraint
      end

      # @constraints.keys.each do |cname|
      #   @indexes.delete("#{schema}.#{cname}") if has_index?(cname)
      # end

      new(constraints)
    end

    def initialize(constraints)
      @constraints = constraints
    end

    def each
      return enum_for(:each) unless block_given?

      @constraints.each do |attribute|
        yield attribute
      end

      self
    end

    def [](name)
      @constraints[name]
    end

    def eql?(other)
      @constraints.eql?(other.instance_variable_get(:@constraints))
    end
    alias :== :eql?

    def definitions
      @constraints.map do |name, constraint|
        constraint.definition
      end
    end

    def definition
      definitions.join('\n')
    end
  end
end
