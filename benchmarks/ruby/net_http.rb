# frozen_string_literal: true
# SPDX-License-Identifier: BSD-3-Clause
#
# Reference workload for the go-ruby-net-http/net-http offline benchmark: the
# same four network-free operations the Go driver runs, expressed against MRI's
# own Net::HTTP / URI. Inputs are built byte-for-byte identically to
# benchmarks/go/main.go; run.sh proves the outputs match (CHECK) before timing.
$stdout.binmode
require "net/http"
require "stringio"
require "uri"
require_relative "_harness"

# Rec + emit: the recording socket the differential oracle uses to capture the
# exact bytes a request writes via Net::HTTPGenericRequest#exec.
class Rec
  attr_reader :buf
  def initialize
    @buf = +""
  end

  def write(*a)
    a.each { |s| @buf << s }
    a.map(&:bytesize).sum
  end

  def continue_timeout
    nil
  end
end

def emit(req, path, ver = "1.1")
  req.set_body_internal(nil)
  s = Rec.new
  req.exec(s, ver, path)
  s.buf
end

# --- deterministic shared inputs (mirror benchmarks/go/main.go) --------------

REQ_FORM_PAIRS = [
  ["title", "Ruby Net::HTTP"],
  ["q", "a b & c=d"],
  ["lang", "en"],
  ["n", "42"],
  ["tag", "café"],
].freeze

FORM_PAIRS = [
  ["q", "ruby net http"],
  ["title", "The Pragmatic Programmer's Guide"],
  ["tags", "a,b,c"],
  ["expr", "1+1=2 & 3>2"],
  ["path", "/usr/local/bin"],
  ["url", "https://example.com/p?x=1&y=2"],
  ["name", "café au lait"],
  ["price", "€19.99"],
  ["pct", "100%"],
  ["star", "*"],
  ["tilde", "a~b"],
  ["space", "one two three"],
  ["amp", "you & me"],
  ["eq", "k=v"],
  ["slash", "a/b/c"],
  ["hash", "a#b"],
  ["plus", "a+b"],
  ["paren", "f(x)"],
  ["quote", '"quoted"'],
  ["semi", "a;b"],
  ["unicode", "日本語"],
  ["empty", ""],
  ["dash", "a-b_c.d"],
  ["n", "1234567890"],
].freeze

CANON_HEADERS = {
  "x-request-id" => "c8f3e1a2-7b04-4d19-9f2a-1e6b0c5d3a77",
  "x-forwarded-for" => "203.0.113.7, 198.51.100.2",
  "x-forwarded-proto" => "https",
  "cache-control" => "no-cache, no-store, max-age=0",
  "content-md5" => "Q2hlY2sgSW50ZWdyaXR5",
  "if-none-match" => '"686897696a7c876b7e"',
  "if-modified-since" => "Wed, 21 Oct 2026 07:28:00 GMT",
  "www-authenticate" => 'Bearer realm="api"',
  "content-language" => "en-US",
  "access-control-allow-origin" => "*",
  "x-content-type-options" => "nosniff",
  "strict-transport-security" => "max-age=63072000; includeSubDomains",
  "referrer-policy" => "no-referrer",
  "x-xss-protection" => "1; mode=block",
  "proxy-authenticate" => 'Basic realm="proxy"',
  "last-modified" => "Tue, 15 Nov 2026 12:45:26 GMT",
}.freeze

RESP_UNIT = "Wikipedia, the free encyclopedia. "
RESP_HEADERS = [
  ["Content-Type", "text/plain; charset=utf-8"],
  ["Server", "go-ruby-net-http-bench"],
  ["Cache-Control", "no-cache"],
  ["Set-Cookie", "session=abc123"],
  ["Set-Cookie", "theme=dark"],
  ["Transfer-Encoding", "chunked"],
].freeze

def resp_body
  (RESP_UNIT * 64).b
end

def resp_raw
  body = resp_body
  s = +"HTTP/1.1 200 OK\r\n"
  RESP_HEADERS.each { |k, v| s << "#{k}: #{v}\r\n" }
  s << "\r\n"
  i = 0
  while i < body.bytesize
    chunk = body.byteslice(i, 200)
    s << format("%x", chunk.bytesize) << "\r\n"
    s << chunk << "\r\n"
    i += 200
  end
  s << "0\r\n\r\n"
  s.b
end

# --- the four network-free operations ----------------------------------------

def build_request
  r = Net::HTTP::Post.new(URI("http://api.example.com/v1/submit"))
  r.set_form_data(REQ_FORM_PAIRS)
  r
end

def build_canon_request
  Net::HTTP::Get.new("/", CANON_HEADERS)
end

def op_request_serialize(req)
  emit(req, "/v1/submit")
end

def op_response_parse(raw)
  io = Net::BufferedIO.new(StringIO.new(raw))
  res = Net::HTTPResponse.read_new(io)
  res.reading_body(io, true) {}
  "#{res.code}|#{res.class.name.sub('Net::', '')}|#{res.body}"
end

def op_form_encode
  URI.encode_www_form(FORM_PAIRS)
end

def op_header_canon(req)
  out = +""
  req.each_capitalized { |k, v| out << "#{k}: #{v}\r\n" }
  out
end

req = build_request
canon = build_canon_request
raw = resp_raw

if ARGV[0] == "verify"
  check("request-serialize", op_request_serialize(req))
  check("response-parse", op_response_parse(raw))
  check("form-encode", op_form_encode)
  check("header-canonicalize", op_header_canon(canon))
  exit
end

bench("request-serialize", 200) { op_request_serialize(req) }
bench("response-parse", 200) { op_response_parse(raw) }
bench("form-encode", 200) { op_form_encode }
bench("header-canonicalize", 200) { op_header_canon(canon) }
