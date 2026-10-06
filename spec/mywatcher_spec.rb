RSpec.shared_context "with file.log in a scratch directory" do
  include_context "with a scratch directory"

  let!(:log) { dir.join("file.log").tap { it.write("old record\n") } }

  after { session.close }

  def append(text)
    log.write(text, mode: "a")
  end
end

RSpec.shared_context "in an interactive shell" do
  let(:session) { InteractiveSession.new(env: Mywatcher.env, dir:) }
end

RSpec.shared_context "without a terminal" do
  let(:session) { DetachedSession.new(env: Mywatcher.env, dir:) }
end

RSpec.shared_examples "stopped by ctrl+c" do
  it "exits, taking its tail with it" do
    session.press_ctrl_c
    expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
  end
end

RSpec.shared_examples "unaffected by ctrl+c" do
  it "keeps following, tail and all" do
    session.press_ctrl_c
    append("after ctrl+c\n")
    expect { session.output }.to eventually(include("record: after ctrl+c"))
    expect(session.watcher).to have_attributes(state: :running, tail_state: :running)
  end
end

RSpec.shared_examples "mywatcher started from a shell" do
  {
    "mywatcher file.log" => "stopped by ctrl+c",
    "mywatcher file.log &" => "unaffected by ctrl+c",
    '(/bin/sh -c "mywatcher file.log &")' => "unaffected by ctrl+c",
    "(mywatcher file.log)" => "stopped by ctrl+c",
    '/bin/sh -c "mywatcher file.log"' => "stopped by ctrl+c",
    "mywatcher file.log | cat" => "stopped by ctrl+c",
    "exec mywatcher file.log" => "stopped by ctrl+c",
    "trap '' INT; mywatcher file.log" => "unaffected by ctrl+c",
    "mywatcher file.log & wait" => "unaffected by ctrl+c",
  }.each do |command, behavior|
    context "with `#{command}`" do
      before { session.start(command) }

      it_behaves_like behavior
    end
  end

  context "when only the watcher is interrupted" do
    before { session.start("mywatcher file.log") }

    it "takes its tail with it" do
      session.watcher.signal(:INT)
      expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
    end
  end

  context "when the watcher is killed outright" do
    before { session.start("mywatcher file.log") }

    it "leaves tail to exit on its broken pipe" do
      session.watcher.signal(:KILL)
      expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
    end
  end

  context "when its tail is killed" do
    before { session.start("mywatcher file.log") }

    it "dies loudly with Tayle::Exited instead of exiting as if done" do
      session.watcher.tail.signal(:KILL)
      expect { session.output }.to eventually(include("Tayle::Exited"))
      expect { session.watcher }.to eventually(have_attributes(state: :gone))
    end
  end
end

RSpec.describe "mywatcher, a CLI built on Tayle" do
  include_context "with file.log in a scratch directory"

  context "in an interactive shell" do
    include_context "in an interactive shell"

    it_behaves_like "mywatcher started from a shell"

    context "when the job is suspended with ctrl+z" do
      before do
        session.start("mywatcher file.log")
        session.press_ctrl_z
      end

      it "suspends its tail with it" do
        expect { session.watcher }.to eventually(have_attributes(state: :stopped, tail_state: :stopped))
      end

      it "resumes both with bg, out of ctrl+c's reach, without losing records" do
        append("while suspended\n")
        session.resume_in_background
        session.press_ctrl_c
        expect { session.output }.to eventually(include("record: while suspended"))
        expect(session.watcher).to have_attributes(state: :running, tail_state: :running)
      end
    end

    context "when a background job is brought back with fg" do
      before do
        session.start("mywatcher file.log &")
        session.bring_to_foreground
      end

      it_behaves_like "stopped by ctrl+c"
    end

    context "when the terminal hangs up" do
      ["mywatcher file.log", "mywatcher file.log &"].each do |command|
        context "with `#{command}`" do
          before { session.start(command) }

          it "takes the watcher and its tail down" do
            session.hang_up
            expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
          end
        end
      end

      context "with `mywatcher file.log & disown`" do
        before do
          session.start("mywatcher file.log & disown")
          session.hang_up
        end

        it "spares both" do
          expect(session.watcher).to have_attributes(state: :running, tail_state: :running)
        end

        it "loses the watcher at its next write to the dead terminal, and its tail with it" do
          append("after hangup\n")
          expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
        end
      end
    end
  end

  context "without a terminal" do
    include_context "without a terminal"

    it_behaves_like "mywatcher started from a shell"

    context "when a supervisor sends SIGTERM to the whole group" do
      before { session.start("mywatcher file.log") }

      it "takes the watcher and its tail down" do
        session.signal_group(:TERM)
        expect { session.watcher }.to eventually(have_attributes(state: :gone, tail_state: :gone))
      end
    end
  end
end
