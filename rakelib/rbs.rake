require "yaml"

namespace :rbs do
  root_dir = Pathname(__dir__).parent
  collection_yaml = root_dir / "rbs_collection.yaml"
  collection_dir = root_dir / ".gem_rbs_collection"
  manifest = root_dir / "sig" / "manifest.yaml"

  # The stdlib signatures sig/manifest.yaml names, as rbs -r flags; the
  # manifest only applies by itself when the gem's sig is loaded as a library.
  stdlib_flags = lambda do
    YAML.safe_load_file(manifest).fetch("dependencies").flat_map { ["-r", it.fetch("name")] }
  end

  desc "Install the rbs collection rbs_collection.lock.yaml pins"
  task setup: ["rbs:collection:install"]

  desc "Remove the installed rbs collection"
  task :clobber do
    rm_rf collection_dir
  end

  desc "Check every signature under sig parses and names only types that exist"
  task validate: ["rbs:collection:install"] do
    sh "bundle", "exec", "rbs", "-I", "sig", *stdlib_flags.call, "validate"
  end

  # Enumerators go unchecked: the checker samples one by iterating, and the
  # Enumerator #each returns blocks on tail until the log grows.
  desc "Run the specs with every Tayle call checked against its signature"
  task test: ["rbs:collection:install"] do
    env = {
      "RBS_TEST_TARGET" => "Tayle,Tayle::*",
      "RBS_TEST_OPT" => ["-I", "sig", *stdlib_flags.call].join(" "),
      "RBS_TEST_LOGLEVEL" => "warn",
      "RBS_TEST_DOUBLE_SUITE" => "rspec",
      "RBS_TEST_UNCHECKED_CLASSES" => "Enumerator",
      "RUBYOPT" => "-r rbs/test/setup",
    }
    sh env, "bundle", "exec", "rspec"
  end

  namespace :collection do
    file collection_yaml.to_s do
      sh "bundle exec rbs collection init"
    end

    desc "Write rbs_collection.yaml if it is missing"
    task init: [collection_yaml.to_s]

    desc "Install the gem RBS files the collection lists"
    task install: ["rbs:collection:init"] do
      sh "bundle exec rbs collection install"
    end

    desc "Re-resolve the collection and rewrite rbs_collection.lock.yaml"
    task :update do
      sh "bundle exec rbs collection update"
    end
  end
end
