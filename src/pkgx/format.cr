module Pkgx
  module Format
    def self.bytes(n : Int64) : String
      return "-" if n <= 0
      if n >= 1_073_741_824
        "%.1f G" % (n / 1_073_741_824.0)
      elsif n >= 1_048_576
        "%.1f M" % (n / 1_048_576.0)
      elsif n >= 1_024
        "%.1f K" % (n / 1_024.0)
      else
        "#{n} B"
      end
    end
  end
end
