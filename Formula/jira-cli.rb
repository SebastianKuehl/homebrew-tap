class JiraCli < Formula
  desc "Minimal Jira CLI to fetch and sync tickets to a knowledge base"
  homepage "https://github.com/SebastianKuehl/jira-cli"
  url "https://github.com/SebastianKuehl/jira-cli/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "33dbe332f5617e48f80c5ff68288d069a7d1c28e7f386006cc3d96d163350ae5"

  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(output: bin/"jira"), "./cmd/jira"
  end

  test do
    assert_predicate bin/"jira", :executable?
  end
end
