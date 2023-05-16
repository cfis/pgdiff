module PgDiff
  class Attribute
    attr_accessor :name, :type_def, :notnull, :default

    def initialize(name, typedef, notnull, default)
      @name = name
      @type_def = typedef
      @notnull = notnull
      @default = default
    end

    def definition
      out = ['    ', @name,  @type_def]
      out << 'NOT NULL' if @notnull
      out << 'DEFAULT ' + @default if @default
      out.join(" ")
    end

    def == (other)
      definition == other.definition
    end
  end
end
