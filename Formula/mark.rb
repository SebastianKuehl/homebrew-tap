class Mark < Formula
  desc "Markdown-to-HTML CLI with automatic browser preview"
  homepage "https://github.com/SebastianKuehl/mark"
  url "https://github.com/SebastianKuehl/mark/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "16a5515759363f945f5128052b7eb261e1b49e7454af6dd5cec970b3758c532b"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mark --version")
  end
end
