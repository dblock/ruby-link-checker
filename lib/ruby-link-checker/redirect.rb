# frozen_string_literal: true

module LinkChecker
  # A redirect hop: uri responded with code and redirected to the resolved target uri, to.
  Redirect = Data.define(:uri, :code, :to) do
    # Whether the hop was a permanent redirect (301 or 308).
    def permanent?
      [301, 308].include?(code)
    end
  end
end
