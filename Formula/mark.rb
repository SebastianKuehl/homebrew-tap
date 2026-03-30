class Mark < Formula
  desc "Markdown-to-HTML CLI with automatic browser preview"
  homepage "https://github.com/SebastianKuehl/mark"
  url "https://github.com/SebastianKuehl/mark/archive/refs/tags/v0.13.1.tar.gz"
  sha256 "2aaf6e13d117b8bd5c4ec9d75236f89149e20710a0c8a8025db3ec4f2525021e"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mark --version")
  end
end
