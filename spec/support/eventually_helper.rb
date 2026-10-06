module EventuallyHelper
  def eventually(expected, within: 3)
    Eventually.new(expected, within:)
  end
end
