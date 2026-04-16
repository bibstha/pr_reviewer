module ReviewsHelper
  def extract_file_diff(diff_raw, file_path)
    return "" if diff_raw.blank?

    lines = diff_raw.split("\n")
    result = []
    in_target_file = false
    found_file = false

    lines.each do |line|
      if line.start_with?("diff --git")
        if line.include?(file_path)
          in_target_file = true
          found_file = true
          result << line
        elsif found_file
          # We've moved past our target file
          break
        else
          in_target_file = false
        end
      elsif in_target_file
        result << line
      end
    end

    result.join("\n")
  end
end
