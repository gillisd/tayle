RSpec.shared_context "with a scratch directory" do
  let(:dir) { Pathname(Dir.mktmpdir) }

  after do
    dir.each_child(&:delete)
    dir.delete
  end
end
