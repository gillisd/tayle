RSpec.describe "Zeitwerk" do
  it "eager loads all files without errors" do
    expect { Tail::LOADER.eager_load(force: true) }.not_to raise_error
  end
end
