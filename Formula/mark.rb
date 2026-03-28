class Mark < Formula
  desc "Markdown-to-HTML CLI with automatic browser preview"
  homepage "https://github.com/SebastianKuehl/mark"
  url "https://github.com/SebastianKuehl/mark/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "31535a5e2864f841367ba8e9da568d598edfbfe2d64950cd3aad805feb4a8901"
  license "MIT"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mark --version")
  end
end
