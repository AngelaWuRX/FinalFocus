from http.server import BaseHTTPRequestHandler, HTTPServer
import json

from agent import generate_plan
from planner_rules import parse_exam_date


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/plan":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", 0))
        payload = json.loads(self.rfile.read(length) or b"{}")
        exam_date = parse_exam_date(payload.get("examDate"))
        response = json.dumps(generate_plan(payload, exam_date)).encode()

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        return


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8787), Handler).serve_forever()
