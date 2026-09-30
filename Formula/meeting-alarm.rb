class MeetingAlarm < Formula
  desc "Loud alarm 15 seconds before a meeting starts"
  homepage "https://github.com/buether/meeting-alarms"
  url "https://github.com/buether/meeting-alarms/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "ff73d6da1c393ba89d6081d8b806929fcea8290f967384558a2c0b560a022b3f"
  license "MIT"

  depends_on xcode: :clt
  depends_on macos: :sonoma

  def install
    app = libexec/"MeetingAlarm.app"
    (app/"Contents/MacOS").mkpath
    system "swiftc", "-target", "#{Hardware::CPU.arch}-apple-macos14.0",
           "-O", "-suppress-warnings",
           "-o", app/"Contents/MacOS/meeting-alarm", *Dir["src/*.swift"]
    (app/"Contents").install "app/Info.plist"
    # Built here rather than downloaded, so nothing is quarantined and an ad-hoc
    # signature is enough for Gatekeeper.
    system "codesign", "--force", "--sign", "-", app
    pkgshare.install "config.example.json"

    (bin/"meeting-alarm").write <<~BASH
      #!/bin/bash
      exec "#{opt_libexec}/MeetingAlarm.app/Contents/MacOS/meeting-alarm" "$@"
    BASH
  end

  def caveats
    <<~TEXT
      Load the background jobs with:
        meeting-alarm install

      They remove themselves within a minute of `brew uninstall`. Config,
      history and logs under ~/Library are left alone.
    TEXT
  end

  test do
    assert_match "watchdog", shell_output("#{bin}/meeting-alarm --help")

    # Exercises the selection logic without touching the calendar.
    (testpath/"events.json").write <<~JSON
      [{"id": "a", "title": "Standup", "startDate": "2026-09-18T12:00:30Z",
        "endDate": "2026-09-18T12:15:00Z", "isAllDay": false, "status": "confirmed",
        "attendees": [{"status": "accepted", "isCurrentUser": false},
                      {"status": "accepted", "isCurrentUser": true}]}]
    JSON
    output = shell_output("#{bin}/meeting-alarm poll --dry-run " \
                          "--now 2026-09-18T12:00:00Z --events-file #{testpath}/events.json")
    assert_match "1 events in window, 1 due", output
  end
end
