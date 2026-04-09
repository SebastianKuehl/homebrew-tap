class JiraCli < Formula
  desc 'Minimal Jira CLI to fetch and sync tickets to a knowledge base.'
  homepage 'https://github.com/SebastianKuehl/jira-cli'
  url 'https://github.com/SebastianKuehl/jira-cli/archive/refs/tags/v0.1.0.tar.gz'
  sha256 'dbb506d1167850c978e8566ef0ba59d488fd4ebfa0c8e17ed1aba46922e325bb'


  depends_on "go" => :build

  def install
    system "go", "build", *std_go_args(output: bin/'jira'), './cmd/jira'
  end

  test do
    assert_predicate bin/'jira', :executable?
  end
end
