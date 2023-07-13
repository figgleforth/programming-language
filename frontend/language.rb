class Language
  Keywords = {
    identifiers:     %w(self bwah),

    pre_blocks:      %w(if else while for),

    block_operators: %w(stop next it index),

    pre_type:        ': ',

    types:           %w(int float str bool list dict),

    comments:        %w(#),

    operators:       %w(+ - * / % = == != < > <= >=),

    # maybe) reserve the word versions as well, eg) and, or, not, etc?
    logical_operators: %w(&& || !),

    loop_operators:    %w(stop next it index),

    # pre_functions: %w(func),
    # functions: %w(),
    # pre_variables: %w(),
    # variables: %w(),
    # pre_operators: %w(),
    # pre_punctuation: %w(),
    # punctuation: %w(),
    # pre_comments: %w(),
    # pre_eof: %w(),
    # eof: %w(),

  }
end
