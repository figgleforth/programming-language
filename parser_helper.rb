module ParserHelper
    def eat tokens, times = 1
        tokens.shift times
    end

    def eat_until tokens, &block
        eat tokens, tokens.slice_before(&block).to_a.first.count
    end

    def eat_past tokens, &block
        eat tokens, tokens.slice_after(&block).to_a.first.count
    end

    def peek tokens, ahead = 1
        tokens.dup.shift ahead
    end

    def peek_until tokens, &block
        tokens.dup.slice_before(&block).to_a.first
    end

    def assert token, type
        raise "Expected #{token.inspect} to be #{type}" if token.type != type
    end

    def reached_end? tokens
        tokens.empty?
    end
end
