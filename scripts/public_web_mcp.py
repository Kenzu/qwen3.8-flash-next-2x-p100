"""Read-only stdio MCP tools for public web searches and documentation pages."""
import http.client
import ipaddress
import json
import re
import socket
import ssl
import sys
import time
import xml.etree.ElementTree as ET
from html.parser import HTMLParser
from urllib.parse import parse_qs, quote, urlencode, urljoin, urlsplit, urlunsplit

MAX_BYTES = 2_000_000
PAGE_CHARS = 10000
TLS = ssl.create_default_context()
TOOLS = [
    {"name": "search", "description": "Search the public web. Returns titles and source URLs. Use fetch to verify a source.",
     "inputSchema": {"type": "object", "properties": {"query": {"type": "string", "description": "One search query, optionally using site:domain."}}, "required": ["query"]}},
    {"name": "fetch", "description": "Read text from a public web page or raw source file. Cite the returned URL. Optionally find a term or continue at an offset.",
     "inputSchema": {"type": "object", "properties": {"url": {"type": "string"}, "find": {"type": "string"}, "offset": {"type": "integer", "minimum": 0}}, "required": ["url"]}},
]


def download(url):
    deadline = time.monotonic() + 16
    for _ in range(6):
        if len(url) > 6000 or any(ord(c) < 32 for c in url):
            raise ValueError("Invalid URL")
        target = urlsplit(url)
        if target.scheme not in ("http", "https") or not target.hostname or target.username is not None or target.password is not None:
            raise ValueError("Provide a public HTTP(S) URL without credentials")
        host = target.hostname.encode("idna").decode()
        port = 443 if target.scheme == "https" else 80
        if target.port not in (None, port):
            raise ValueError("Only standard public web ports are available")
        addresses = socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)
        for _, _, _, _, address in addresses:
            ip = ipaddress.ip_address(address[0])
            if not ip.is_global or ip.is_multicast or ip.is_reserved:
                raise ValueError("Only public internet addresses are available")
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError("Page request timed out")
        # Connect to the checked numeric address. The original name is used for TLS and HTTP.
        with socket.create_connection(addresses[0][4], timeout=min(8, remaining)) as sock:
            conn = http.client.HTTPConnection(host, port)
            try:
                conn.sock = TLS.wrap_socket(sock, server_hostname=host) if target.scheme == "https" else sock
                path = quote(urlunsplit(("", "", target.path or "/", target.query, "")), safe="/%?&=:+,;@!$()*~'")
                conn.request("GET", path, headers={"User-Agent": "Strata-Web/1.0", "Accept-Encoding": "identity"})
                response = conn.getresponse()
                if response.status in (301, 302, 303, 307, 308):
                    dest = response.getheader("Location")
                    if not dest:
                        raise ValueError("Redirect has no target")
                    url = urljoin(url, dest)
                    continue
                if response.status != 200:
                    raise ValueError(f"Source returned HTTP {response.status}")
                mime = response.headers.get_content_type()
                if not (mime.startswith("text/") or mime in ("application/json", "application/xml", "application/rss+xml", "application/xhtml+xml", "application/toml", "application/octet-stream")):
                    raise ValueError(f"Unsupported document type: {mime}")
                buf = bytearray()
                while len(buf) <= MAX_BYTES:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise ValueError("Page request timed out")
                    if conn.sock:
                        conn.sock.settimeout(min(8, remaining))
                    part = response.read1(min(65536, MAX_BYTES + 1 - len(buf)))
                    if not part:
                        break
                    buf.extend(part)
                if b"\x00" in buf[:4096]:
                    raise ValueError("The document is binary")
                text = bytes(buf[:MAX_BYTES]).decode(response.headers.get_content_charset() or "utf-8", errors="replace")
                return url, mime, text, len(buf) > MAX_BYTES
            finally:
                conn.close()
    raise ValueError("Too many redirects")


class PageText(HTMLParser):
    skip_tags = {"script", "style", "svg", "noscript", "nav", "footer", "template"}
    breaks = {"p", "div", "br", "pre", "li", "tr", "h1", "h2", "h3", "h4", "section"}

    def __init__(self, base):
        super().__init__()
        self.base = base
        self.parts = []
        self.hidden = []
        self.search_results = []
        self.result_link = None

    def handle_starttag(self, tag, attrs):
        if tag in self.skip_tags:
            self.hidden.append(tag)
        if self.hidden:
            return
        if tag in self.breaks:
            self.parts.append("\n")
        a = dict(attrs)
        if tag == "a" and "result-link" in (a.get("class") or "").split():
            self.result_link = [a.get("href") or "", []]

    def handle_endtag(self, tag):
        if self.hidden:
            if tag == self.hidden[-1]:
                self.hidden.pop()
            return
        if tag in self.breaks:
            self.parts.append("\n")
        if tag == "a" and self.result_link:
            raw, words = self.result_link
            target = urljoin(self.base, raw)
            p = urlsplit(target)
            if p.hostname in ("duckduckgo.com", "lite.duckduckgo.com") and p.path.startswith("/l/"):
                target = parse_qs(p.query).get("uddg", [""])[0]
            if urlsplit(target).scheme in ("http", "https"):
                self.search_results.append({"title": " ".join("".join(words).split()), "url": target})
            self.result_link = None

    def handle_data(self, data):
        if not self.hidden:
            self.parts.append(data)
            if self.result_link:
                self.result_link[1].append(data)


def search(query):
    if not isinstance(query, str) or not 1 <= len(query.strip()) <= 600:
        raise ValueError("Provide one query up to 600 characters")
    q = urlencode({"q": query})
    try:
        url, _, html, _ = download("https://lite.duckduckgo.com/lite/?" + q)
        page = PageText(url)
        page.feed(html)
        if page.search_results:
            return {"source": "DuckDuckGo", "results": page.search_results[:7]}
    except (ValueError, OSError, http.client.HTTPException):
        pass
    _, _, rss, _ = download("https://www.bing.com/search?format=rss&" + q)
    rows = [{"title": item.findtext("title"), "url": item.findtext("link"), "snippet": (item.findtext("description") or "")[:300]}
            for item in ET.fromstring(rss).findall("./channel/item") if item.findtext("link")]
    return {"source": "Bing", "results": rows[:7]}


def fetch(url, find="", offset=0):
    if not isinstance(url, str) or not isinstance(find, str) or len(find) > 300 or type(offset) is not int or offset < 0:
        raise ValueError("Expected a URL, optional search term and non-negative offset")
    url, mime, text, partial = download(url)
    if "html" in mime:
        page = PageText(url)
        page.feed(text)
        text = re.sub(r"\n(?:[ \t]*\n)+", "\n", "".join(page.parts)).strip()
    if find:
        match = text.casefold().find(find.casefold(), offset)
        if match < 0:
            return {"url": url, "found": False, "source_truncated": partial}
        offset = max(offset, match - 450)
    end = min(len(text), offset + PAGE_CHARS)
    return {"url": url, "offset": offset, "next_offset": end if end < len(text) else None,
            "source_truncated": partial, "text": text[offset:end]}


def dispatch(msg):
    method = msg.get("method")
    params = msg.get("params") or {}
    if method == "initialize":
        return {"protocolVersion": params.get("protocolVersion", "2025-06-18"),
                "serverInfo": {"name": "public-web", "version": "1.0"}, "capabilities": {"tools": {}}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        try:
            func = {"search": search, "fetch": fetch}[params["name"]]
            result = func(**params.get("arguments", {}))
            return {"content": [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}]}
        except (ValueError, KeyError, TypeError, OSError, http.client.HTTPException, ET.ParseError, LookupError) as exc:
            return {"isError": True, "content": [{"type": "text", "text": str(exc)}]}
    raise ValueError("Unsupported MCP method")


if __name__ == "__main__":
    for line in sys.stdin:
        try:
            message = json.loads(line)
            if "id" not in message:
                continue
            response = {"jsonrpc": "2.0", "id": message["id"]}
            try:
                response["result"] = dispatch(message)
            except ValueError as error:
                response["error"] = {"code": -32601, "message": str(error)}
            print(json.dumps(response), flush=True)
        except (ValueError, TypeError):
            continue
