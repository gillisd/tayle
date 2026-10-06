RSpec.describe Tayle do
  include_context "with a scratch directory"

  let(:log) { dir.join("app.log").tap { it.write("old record\n") } }
  let(:tail_process) { ProcessProbe.new }

  def follow(path, **options, &block)
    tail_process.watch { described_class.new(path, **options, &block) }
  end

  def append(text)
    log.write(text, mode: "a")
  end

  def kill_tail
    OsProcess.new(pid: Process.pid).spawned_tail.signal(:KILL)
  end

  def write_script(body)
    dir.join("tail").tap do |script|
      script.write("#!/bin/sh\n#{body}\n")
      script.chmod(0o755)
    end
  end

  shared_examples "loud when tail is killed" do
    it "raises Tayle::Exited from #each, with tail's status" do
      kill_tail
      expect { tayle.first }.to raise_error(Tayle::Exited, /SIGKILL/) { expect(it.status.termsig).to eq(9) }
    end
  end

  shared_examples "ended by its writer" do
    it "ends #each once the writer is gone, after yielding its last records" do
      writer.puts("go")
      writer.close
      expect(tayle.to_a).to eq(["last record\n"])
    end
  end

  context "when following a log" do
    subject!(:tayle) { follow(log) }

    after { tayle.close }

    describe "#each" do
      it "yields only records appended after it was opened" do
        append("new record\n")
        expect(tayle.first).to eq("new record\n")
      end

      it "blocks until the next record arrives" do
        reader = Thread.new { tayle.first }
        Thread.pass until reader.stop?
        expect(reader).to be_alive
        append("late record\n")
        expect(reader.value).to eq("late record\n")
      end

      it_behaves_like "loud when tail is killed"
    end

    describe "#each_line" do
      it "strips line endings with chomp: true" do
        append("new record\n")
        expect(tayle.each_line(chomp: true).first).to eq("new record")
      end

      it "returns an Enumerator that composes lazily" do
        append("a\nb\n")
        expect(tayle.each_line(chomp: true).lazy.map(&:upcase).first(2)).to eq(["A", "B"])
      end
    end

    describe "#position" do
      it "is :end by default" do
        expect(tayle.position).to eq(:end)
      end
    end

    describe "#lines_read" do
      it "starts at zero" do
        expect(tayle.lines_read).to eq(0)
      end

      it "counts every line yielded, across iterations" do
        append("a\nb\nc\n")
        tayle.first
        tayle.each_line(chomp: true).first(2)
        expect(tayle.lines_read).to eq(3)
      end

      it "keeps its count after #close" do
        append("a\nb\n")
        tayle.first(2)
        tayle.close
        expect(tayle.lines_read).to eq(2)
      end
    end

    describe "#close" do
      it "kills the tail process" do
        expect { tayle.close }.to change { tail_process.exited? }.from(false).to(true)
      end

      it "makes further reads raise IOError" do
        tayle.close
        expect { tayle.first }.to raise_error(IOError, "closed stream")
      end

      it "can be called more than once" do
        tayle.close
        expect { tayle.close }.not_to raise_error
      end

      context "when called in a forked child" do
        before do
          child = fork do
            tayle.close
            exit!
          end
          Process.wait(child)
        end

        it "leaves the parent's tail running" do
          expect(tail_process).not_to be_exited
          append("new record\n")
          expect(tayle.first).to eq("new record\n")
        end
      end

      context "when a forked child shares the pipe" do
        let!(:child) { fork { sleep } }

        after do
          Process.kill(:KILL, child)
          Process.wait(child)
        end

        it "still kills the tail process" do
          expect { tayle.close }.to change { tail_process.exited? }.from(false).to(true)
        end

        context "and tail inherited an ignored SIGTERM" do
          around do |example|
            previous = trap("TERM", "IGNORE")
            begin
              example.run
            ensure
              trap("TERM", previous)
            end
          end

          it "still kills the tail process" do
            expect { tayle.close }.to change { tail_process.exited? }.from(false).to(true)
          end
        end
      end
    end

    context "when the log is rotated" do
      it "follows the name onto the new file" do
        append("before rotation\n")
        expect(tayle.first).to eq("before rotation\n")
        log.rename("#{log}.1")
        append("after rotation\n")
        expect(tayle.first).to eq("after rotation\n")
      end
    end

    context "when the log is truncated" do
      it "reads it again from the start" do
        append("before truncation\n")
        expect(tayle.first).to eq("before truncation\n")
        log.truncate(0)
        append("after truncation\n")
        expect(tayle.first).to eq("after truncation\n")
      end
    end

    context "when its path looks like an option" do
      let(:log) { Pathname("-v.log").tap { it.write("old record\n") } }

      around { |example| Dir.chdir(dir) { example.run } }

      it "still treats it as a path" do
        append("new record\n")
        expect(tayle.first).to eq("new record\n")
      end
    end

    context "when the log does not exist yet" do
      let(:log) { dir.join("app.log") }

      before { tail_process.await_warning }

      it "yields its records once it appears" do
        append("first record\n")
        expect(tayle.first).to eq("first record\n")
      end

      it "polls for records ten times a second" do
        append("first record\n")
        tayle.first
        append("second record\n")
        expect(Timeout.timeout(0.5) { tayle.first }).to eq("second record\n")
      end
    end
  end

  describe ".new" do
    it "accepts a String path, reporting it as a Pathname" do
      expect(follow(log.to_s, &:itself).path).to eq(log)
    end

    it "rejects a writer_pid that isn't an integer" do
      expect { described_class.new(log, writer_pid: "not-a-pid") }.to raise_error(ArgumentError)
    end

    it "rejects a position other than :start or :end" do
      message = "position: must be :start or :end, not :middle"
      expect { described_class.new(log, position: :middle) }.to raise_error(ArgumentError, message)
    end

    context "with position: :start" do
      subject!(:tayle) { follow(log, position: :start) }

      after { tayle.close }

      it "yields what the log already holds, then what is appended" do
        append("new record\n")
        expect(tayle.first(2)).to eq(["old record\n", "new record\n"])
      end

      it "reports :start as its position" do
        expect(tayle.position).to eq(:start)
      end
    end

    context "with a tail_path" do
      let(:wrapper) { write_script(<<~SH) }
        [ "$1" = --version ] || echo "via wrapper"
        exec tail "$@"
      SH

      it "follows with that tail" do
        follow(log, tail_path: wrapper) { expect(it.first).to eq("via wrapper\n") }
      end

      it "resolves a path with a slash against the working directory" do
        wrapper
        Dir.chdir(dir) { follow(log, tail_path: "./tail") { expect(it.first).to eq("via wrapper\n") } }
      end

      it "accepts GNU coreutils 8.28" do
        tail_path = write_script("echo 'tail (GNU coreutils) 8.28'")
        expect { follow(log, tail_path:, &:itself) }.not_to raise_error
      end

      it "rejects GNU coreutils 8.27, naming its version" do
        tail_path = write_script("echo 'tail (GNU coreutils) 8.27'")
        message = "#{tail_path} is GNU coreutils tail 8.27; Tayle needs 8.28 or newer"
        expect { follow(log, tail_path:) }.to raise_error(Tayle::Unsupported, message)
      end

      it "rejects a tail that isn't GNU's, whatever its version" do
        tail_path = write_script("echo 'tail (uutils coreutils) 9.9'")
        expect { follow(log, tail_path:) }.to raise_error(Tayle::Unsupported, "#{tail_path} is not GNU coreutils tail")
      end

      it "rejects a directory" do
        tail_path = dir.join("tail").tap(&:mkdir)
        message = "#{tail_path} not found or not executable"
        expect { follow(log, tail_path:) }.to raise_error(Tayle::Unsupported, message)
      end

      it "rejects a file that isn't executable" do
        tail_path = dir.join("tail").tap { it.write("") }
        message = "#{tail_path} not found or not executable"
        expect { follow(log, tail_path:) }.to raise_error(Tayle::Unsupported, message)
      end

      it "rejects a path that doesn't exist" do
        tail_path = dir.join("missing")
        message = "#{tail_path} not found or not executable"
        expect { follow(log, tail_path:) }.to raise_error(Tayle::Unsupported, message)
      end
    end

    context "with the writer's pid" do
      subject!(:tayle) { follow(log, writer_pid: writer.pid) }

      let(:writer) { IO.popen(["sh", "-c", 'read go && printf "last record\n" >> "$1"', "sh", log.to_s], mode: "w") }

      after do
        tayle.close
        writer.close
      end

      it_behaves_like "ended by its writer"
      it_behaves_like "loud when tail is killed"

      context "when the log does not exist yet" do
        let(:log) { dir.join("app.log") }

        before { tail_process.await_warning }

        it_behaves_like "ended by its writer"
      end
    end

    context "with a block" do
      it "yields the tayle" do
        expect { |block| follow(log, &block) }.to yield_with_args(described_class)
      end

      it "closes it once the block returns" do
        follow(log, &:itself)
        expect(tail_process).to be_exited
      end

      it "closes it even when the block raises" do
        expect { follow(log) { raise "boom" } }.to raise_error(RuntimeError, "boom")
        expect(tail_process).to be_exited
      end
    end
  end

  describe "VERSION" do
    it "has a version number" do
      expect(described_class::VERSION).not_to be_nil
    end
  end
end
