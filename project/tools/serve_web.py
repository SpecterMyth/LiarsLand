from __future__ import annotations

import json
import mimetypes
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WEB_ROOT = ROOT / "web"
CONFIG_PATH = ROOT / "config.local.json"
HOST = "127.0.0.1"
PORT = 8097


class LiarsLandHandler(BaseHTTPRequestHandler):
    server_version = "LiarsLandWeb/0.1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stdout.write("%s - %s\n" % (self.address_string(), fmt % args))

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/":
            path = "/index.html"
        target = (WEB_ROOT / path.lstrip("/")).resolve()
        if not str(target).startswith(str(WEB_ROOT.resolve())) or not target.is_file():
            self._json_error(404, "not found")
            return

        mime, _ = mimetypes.guess_type(target.name)
        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", mime or "application/octet-stream")
        self.send_header("Content-Length", str(target.stat().st_size))
        self.end_headers()
        self.wfile.write(target.read_bytes())

    def do_POST(self) -> None:
        if self.path.split("?", 1)[0] != "/api/chat":
            self._json_error(404, "not found")
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            cfg = self._load_config()
            if cfg.get("game", {}).get("use_mock_llm"):
                self._json(200, {"content": self._mock_chat(data)})
                return
            if data.get("stream"):
                self._forward_chat_stream(data)
                return
            content = self._forward_chat(data)
            self._json(200, {"content": content})
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            self._json_error(exc.code, detail[:1200])
        except Exception as exc:
            self._json_error(500, str(exc))

    def _forward_chat(self, data: dict) -> str:
        cfg = self._load_config()
        section = data.get("section")
        if section not in ("player_llm", "opponent_llm", "npc_llm"):
            raise ValueError("invalid LLM section")
        llm = cfg.get(section, {})
        if section == "npc_llm" and not llm:
            llm = cfg.get("opponent_llm", {})
        base_url = str(llm.get("base_url", "")).rstrip("/")
        api_key = str(llm.get("api_key", ""))
        model = str(llm.get("model", ""))
        if not base_url or not api_key or api_key.startswith("YOUR_") or not model:
            raise ValueError(f"{section} is not configured")

        endpoint = self._chat_endpoint(base_url)
        body = {
            "model": model,
            "messages": [
                {"role": "system", "content": str(data.get("system_prompt", ""))},
                {"role": "user", "content": str(data.get("user_prompt", ""))},
            ],
            "temperature": 0.8,
            "response_format": {"type": "json_object"},
        }
        payload = self._post_json(endpoint, api_key, body)
        choices = payload.get("choices", [])
        if choices:
            return str(choices[0].get("message", {}).get("content", ""))
        return json.dumps(payload, ensure_ascii=False)

    def _mock_chat(self, data: dict) -> str:
        section = data.get("section")
        user = str(data.get("user_prompt", ""))
        if section == "npc_llm":
            return json.dumps(
                {
                    "speech": "你问得很巧。夜市里的债契从不只写在纸上，有些规矩要看谁敢说出口。"
                },
                ensure_ascii=False,
            )
        if "请选择行动" in user or "行动决策" in user:
            return json.dumps(
                {
                    "thinking": "目前线索仍不够确定，先撤离能保留情报并降低身份暴露风险。",
                    "action": "leave",
                },
                ensure_ascii=False,
            )
        return json.dumps(
            {
                "thinking": "我会围绕公开资料和偏好话题试探，不直接暴露身份卡，也不假设对方的真实立场。",
                "speech": "听说夜市的债契最近比金印还贵。你觉得这类传闻通常会从谁手里流出来？",
                "action": "none",
                "end_dialogue": False,
            },
            ensure_ascii=False,
        )

    def _forward_chat_stream(self, data: dict) -> None:
        cfg = self._load_config()
        section = data.get("section")
        if section not in ("player_llm", "opponent_llm", "npc_llm"):
            raise ValueError("invalid LLM section")
        llm = cfg.get(section, {})
        if section == "npc_llm" and not llm:
            llm = cfg.get("opponent_llm", {})
        base_url = str(llm.get("base_url", "")).rstrip("/")
        api_key = str(llm.get("api_key", ""))
        model = str(llm.get("model", ""))
        if not base_url or not api_key or api_key.startswith("YOUR_") or not model:
            raise ValueError(f"{section} is not configured")

        endpoint = self._chat_endpoint(base_url)
        body = {
            "model": model,
            "messages": [
                {"role": "system", "content": str(data.get("system_prompt", ""))},
                {"role": "user", "content": str(data.get("user_prompt", ""))},
            ],
            "temperature": 0.8,
            "stream": True,
        }
        request = urllib.request.Request(
            endpoint,
            data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "Accept": "text/event-stream",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=90) as response:
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "text/event-stream; charset=utf-8")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            while True:
                line = response.readline()
                if not line:
                    break
                self.wfile.write(line)
                self.wfile.flush()

    def _chat_endpoint(self, base_url: str) -> str:
        normalized = base_url.rstrip("/")
        if normalized.endswith("/chat/completions"):
            return normalized
        return f"{normalized}/chat/completions"

    def _post_json(self, url: str, api_key: str, body: dict) -> dict:
        request = urllib.request.Request(
            url,
            data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            if "response_format" not in detail:
                raise
            body.pop("response_format", None)
            retry = urllib.request.Request(
                url,
                data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                method="POST",
            )
            with urllib.request.urlopen(retry, timeout=90) as response:
                return json.loads(response.read().decode("utf-8"))

    def _load_config(self) -> dict:
        if not CONFIG_PATH.exists():
            raise FileNotFoundError(f"Missing {CONFIG_PATH}")
        return json.loads(CONFIG_PATH.read_text(encoding="utf-8-sig"))

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")

    def _json(self, status: int, body: dict) -> None:
        raw = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self._cors()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _json_error(self, status: int, message: str) -> None:
        self._json(status, {"error": message})


def main() -> None:
    if not WEB_ROOT.exists():
        raise SystemExit(f"Missing web export directory: {WEB_ROOT}")
    httpd = ThreadingHTTPServer((HOST, PORT), LiarsLandHandler)
    print(f"Serving LiarsLand web build at http://{HOST}:{PORT}/index.html")
    print(f"Reading LLM config from {CONFIG_PATH}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
