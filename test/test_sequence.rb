require File.expand_path('./test_helper', __dir__)

class TestSequence < TestCase
  def test_load
    sequences = PgDiff::Sequence.from_database(self.source_connection)
    assert_equal(2, sequences.length)

    sequences = sequences.to_a

    sequence = sequences[0]
    assert_equal("public", sequence.schema)
    assert_equal("shared_sequence", sequence.name)

    sequence = sequences[1]
    assert_equal("public", sequence.schema)
    assert_equal("source_sequence", sequence.name)
  end

  def test_load_all
    sequences = PgDiff::Sequence.from_database(self.source_connection, [])
    assert_equal(2, sequences.length)

    sequences = sequences.to_a

    sequence = sequences[0]
    assert_equal("public", sequence.schema)
    assert_equal("shared_sequence", sequence.name)

    sequence = sequences[1]
    assert_equal("public", sequence.schema)
    assert_equal("source_sequence", sequence.name)
  end

  def test_compare
    source = PgDiff::Sequence.from_database(self.source_connection)
    target = PgDiff::Sequence.from_database(self.target_connection)

    output = StringIO.new
    PgDiff::Sequence.compare(source, target, output)
    expected = <<~EOS
      -- ==== Sequences ====
      DROP SEQUENCE public.source_sequence CASCADE;
      CREATE SEQUENCE public.target_sequence;
    EOS
    assert_equal(expected.strip, output.string.strip)
  end
end
