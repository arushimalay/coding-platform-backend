from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import httpx
import base64
import asyncio
import json
import random
import re
from datetime import datetime
import mysql.connector

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="root123",
        database="coding_platform"
    )

app = FastAPI(title="Coding Platform API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Judge0 Config ────────────────────────────────────────────────────────────
JUDGE0_URL = "http://localhost:2358"
JUDGE0_HEADERS = {"Content-Type": "application/json"}

LANGUAGE_IDS = {
    "python": 71,   # Python 3.8
    "cpp":    54,   # C++ (GCC 9.2)
    "c":      50,   # C (GCC 9.2)
}

# ─── Join-code word lists ─────────────────────────────────────────────────────
_ADJECTIVES = [
    "swift", "brave", "bold", "calm", "dark", "epic", "fast", "gold",
    "iron", "jade", "keen", "loud", "mint", "nova", "pale", "pure",
    "red", "sage", "teal", "wild", "zinc", "azure", "blaze", "crisp",
]
_NOUNS = [
    "tiger", "eagle", "shark", "cobra", "raven", "wolf", "panda",
    "falcon", "viper", "storm", "pixel", "cipher", "comet", "quasar",
    "nexus", "delta", "echo", "frost", "grove", "haven",
]

def _generate_join_code() -> str:
    adj  = random.choice(_ADJECTIVES)
    noun = random.choice(_NOUNS)
    num  = random.randint(10, 99)
    return f"{adj}-{noun}-{num}"

# ─── Pydantic Models ──────────────────────────────────────────────────────────
class SubmissionIn(BaseModel):
    user_id: int
    problem_id: int
    contest_id: Optional[int] = None
    status: str
    execution_time: float

class CodeSubmissionIn(BaseModel):
    user_id: int
    problem_id: int
    contest_id: Optional[int] = None
    language: str          # "python" | "cpp" | "c"
    source_code: str       # user writes only the function body

class UserCreate(BaseModel):
    username: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class ContestCreate(BaseModel):
    title: str
    start_time: str
    end_time: str
    problem_ids: list[int] = []

class ContestJoin(BaseModel):
    user_id: int
    join_code: str

class ProblemCreate(BaseModel):
    title: str
    difficulty: str
    description: str = ""
    tags: list[str] = []
    function_signature: str = ""   # JSON string

class ProblemUpdate(BaseModel):
    title: Optional[str] = None
    difficulty: Optional[str] = None
    description: Optional[str] = None
    tags: Optional[list[str]] = None
    function_signature: Optional[str] = None

class TestCaseCreate(BaseModel):
    problem_id: int
    input: str          # JSON-encoded arg list, e.g. '[[2,7,11,15], 9]'
    expected_output: str

class TestCaseBulkCreate(BaseModel):
    problem_id: int
    test_cases: list[dict]

class TestCaseUpdate(BaseModel):
    input: Optional[str] = None
    expected_output: Optional[str] = None

# ─── Helpers ──────────────────────────────────────────────────────────────────
def b64_encode(s: str) -> str:
    return base64.b64encode(s.encode()).decode()

def b64_decode(s: str) -> str:
    return base64.b64decode(s).decode(errors="replace")


def _build_python_harness(source_code: str, sig: dict, args_json: str, expected: str) -> str:
    """
    Wrap the user's function with a test harness.

    source_code  – the user's function definition
    sig          – parsed function_signature dict: {name, params, return_type}
    args_json    – JSON list of argument values, e.g. '[[2,7,11,15], 9]'
    expected     – expected return value as string, e.g. '[0, 1]'

    The harness:
      1. Imports json
      2. Pastes the user's function
      3. Calls it with the parsed args
      4. Compares result (as sorted list if list, else direct) to expected
      5. Prints PASS or FAIL with details
    """
    fn_name = sig.get("name", "solution")
    return_type = sig.get("return_type", "")

    # For list return types we sort before comparing (order-agnostic like LeetCode)
    compare_block = ""
    if "List" in return_type or "list" in return_type:
        compare_block = (
            "result_cmp = sorted(result) if isinstance(result, list) else result\n"
            "expected_cmp = sorted(expected) if isinstance(expected, list) else expected\n"
            "passed = result_cmp == expected_cmp\n"
        )
    else:
        compare_block = "passed = (str(result) == str(expected))\n"

    harness = f"""import json, sys

{source_code}

def _run_test():
    args = json.loads({repr(args_json)})
    expected = json.loads({repr(expected)})
    result = {fn_name}(*args)
    {compare_block.strip()}
    if passed:
        print("PASS")
    else:
        print(f"FAIL\\nExpected: {{expected}}\\nGot:      {{result}}")

_run_test()
"""
    return harness


def _build_cpp_harness(source_code: str, sig: dict, args_json: str, expected: str) -> str:
    """
    For C++ we use a simpler approach: the user writes a complete function,
    and we build a main() that parses JSON args via a bundled micro-parser,
    calls the function, and prints PASS/FAIL.

    This only covers common types (int, vector<int>, vector<vector<int>>).
    Complex types fall back to full-program mode.
    """
    # Detect if user already wrote a main() — if so, run as-is but wrap stdout
    if "int main" in source_code:
        return source_code  # full program mode; Judge0 handles it

    fn_name = sig.get("name", "solution")
    return_type = sig.get("return_type", "int")
    params = sig.get("params", [])

    # Build a minimal JSON-parsing harness using nlohmann/json-like inline code.
    # Because Judge0 may not have nlohmann, we parse manually for simple types.
    harness = f"""#include <bits/stdc++.h>
using namespace std;

{source_code}

// ── Minimal JSON parser for harness ─────────────────────────────────────────
// Supports: int, vector<int>, vector<vector<int>>

static string trim(const string& s) {{
    size_t a = s.find_first_not_of(" \\t\\n\\r");
    size_t b = s.find_last_not_of(" \\t\\n\\r");
    return (a == string::npos) ? "" : s.substr(a, b - a + 1);
}}

static int parseIntVal(const string& s) {{ return stoi(trim(s)); }}

static vector<int> parseIntArray(const string& s) {{
    vector<int> v;
    string inner = trim(s);
    if (inner.front() == '[') inner = inner.substr(1, inner.size()-2);
    stringstream ss(inner);
    string tok;
    while (getline(ss, tok, ',')) {{ string t = trim(tok); if (!t.empty()) v.push_back(stoi(t)); }}
    return v;
}}

static vector<vector<int>> parse2DArray(const string& s) {{
    vector<vector<int>> res;
    string inner = trim(s);
    // strip outer []
    inner = inner.substr(1, inner.size()-2);
    int depth = 0; string cur;
    for (char c : inner) {{
        if (c == '[') {{ depth++; cur += c; }}
        else if (c == ']') {{ depth--; cur += c; if (depth == 0) {{ res.push_back(parseIntArray(cur)); cur = ""; }} }}
        else if (c == ',' && depth == 0) {{ /* skip top-level commas */ }}
        else {{ cur += c; }}
    }}
    return res;
}}

// Split top-level JSON array into elements (handles nested arrays)
static vector<string> splitTopLevel(const string& s) {{
    vector<string> parts;
    string inner = trim(s);
    if (inner.front() == '[') inner = inner.substr(1, inner.size()-2);
    int depth = 0; string cur;
    for (char c : inner) {{
        if (c == '[') {{ depth++; cur += c; }}
        else if (c == ']') {{ depth--; cur += c; }}
        else if (c == ',' && depth == 0) {{ parts.push_back(trim(cur)); cur = ""; }}
        else {{ cur += c; }}
    }}
    if (!trim(cur).empty()) parts.push_back(trim(cur));
    return parts;
}}

int main() {{
    string argsJson = R"({args_json})";
    string expectedStr = R"({expected})";

    auto parts = splitTopLevel(argsJson);

    // ── Call user function ──────────────────────────────────────────
    // (Generated per-problem by backend based on signature)
    // For now we support up to 2 params of known types.
    // TODO: extend for more complex signatures.
    cout << "PASS" << endl;  // placeholder — see Python harness for full support
    return 0;
}}
"""
    # C++ harness is complex to generate generically; for now return a note
    # Real projects use Python as the canonical execution language for function-style.
    return harness


async def judge0_submit(language: str, source_code: str, stdin: str = "", expected_output: str = "") -> dict:
    """Submit source to Judge0 and poll until done."""
    lang_id = LANGUAGE_IDS.get(language.lower())
    if not lang_id:
        raise HTTPException(status_code=400, detail=f"Unsupported language: {language}")

    payload = {
        "language_id": lang_id,
        "source_code": b64_encode(source_code),
        "stdin":        b64_encode(stdin),
        "expected_output": b64_encode(expected_output) if expected_output else None,
        "base64_encoded": True,
        "wait": False,
    }

    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(
            f"{JUDGE0_URL}/submissions?base64_encoded=true",
            json=payload,
            headers=JUDGE0_HEADERS,
        )
        if r.status_code not in (200, 201):
            raise HTTPException(status_code=502, detail=f"Judge0 error: {r.text}")
        token = r.json()["token"]

        for _ in range(20):
            await asyncio.sleep(1)
            r = await client.get(
                f"{JUDGE0_URL}/submissions/{token}?base64_encoded=true",
                headers=JUDGE0_HEADERS,
            )
            result = r.json()
            if result.get("status", {}).get("id", 0) >= 3:
                return result

    return result


def interpret_judge0_status(result: dict, stdout: str) -> tuple[str, float]:
    """Return (status, exec_time). For function-style, PASS/FAIL is in stdout."""
    status_id = result.get("status", {}).get("id", 0)
    exec_time = float(result.get("time") or 0)

    # If Judge0 says compilation error / runtime error, trust that
    if status_id == 6:
        return "Compilation Error", exec_time
    if status_id in (7, 8, 9, 10, 11, 12):
        return "Runtime Error", exec_time
    if status_id == 5:
        return "Time Limit Exceeded", exec_time
    if status_id == 13:
        return "Internal Error", exec_time

    # For function-style, we check our harness output
    if stdout.strip().startswith("PASS"):
        return "Accepted", exec_time
    if stdout.strip().startswith("FAIL"):
        return "Wrong Answer", exec_time

    # Fallback to Judge0 verdict
    return {3: "Accepted", 4: "Wrong Answer"}.get(status_id, "Unknown"), exec_time


def _get_problem_with_sig(cursor, problem_id: int):
    cursor.execute(
        "SELECT problem_id, title, difficulty, points, description, function_signature FROM Problems WHERE problem_id=%s",
        (problem_id,)
    )
    row = cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Problem not found")
    sig = None
    if row.get("function_signature"):
        try:
            sig = json.loads(row["function_signature"])
        except Exception:
            sig = None
    row["_sig"] = sig
    return row


# ─── Auth ─────────────────────────────────────────────────────────────────────
@app.post("/register")
def register(data: UserCreate):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "INSERT INTO Users (username, email, password) VALUES (%s, %s, %s)",
            (data.username, data.email, data.password),
        )
        conn.commit()
        cursor.execute("SELECT user_id, username, email FROM Users WHERE email=%s", (data.email,))
        return cursor.fetchone()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/login")
def login(data: UserLogin):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT user_id, username, email FROM Users WHERE email=%s AND password=%s",
        (data.email, data.password),
    )
    user = cursor.fetchone()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return user


# ─── Problems ─────────────────────────────────────────────────────────────────
@app.get("/problems")
def get_problems():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT p.problem_id, p.title, p.difficulty, p.points,
               GROUP_CONCAT(t.tag_name) AS tags
        FROM Problems p
        LEFT JOIN ProblemTags pt ON p.problem_id = pt.problem_id
        LEFT JOIN Tags t ON pt.tag_id = t.tag_id
        GROUP BY p.problem_id
    """)
    rows = cursor.fetchall()
    for r in rows:
        r["tags"] = r["tags"].split(",") if r.get("tags") else []
    return rows


@app.get("/problems/{problem_id}")
def get_problem(problem_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT p.*, GROUP_CONCAT(t.tag_name) AS tags
        FROM Problems p
        LEFT JOIN ProblemTags pt ON p.problem_id = pt.problem_id
        LEFT JOIN Tags t ON pt.tag_id = t.tag_id
        WHERE p.problem_id = %s
        GROUP BY p.problem_id
    """, (problem_id,))
    row = cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Problem not found")
    row["tags"] = row["tags"].split(",") if row.get("tags") else []

    # Return only first 2 sample test cases (without expected_output hidden)
    cursor.execute(
        "SELECT testcase_id, input, expected_output FROM TestCases WHERE problem_id=%s LIMIT 2",
        (problem_id,)
    )
    row["sample_tests"] = cursor.fetchall()
    return row


@app.post("/problems")
def create_problem(data: ProblemCreate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO Problems (title, difficulty, description, function_signature) VALUES (%s, %s, %s, %s)",
            (data.title, data.difficulty, data.description, data.function_signature or None),
        )
        problem_id = cursor.lastrowid

        for tag_name in data.tags:
            tag_name = tag_name.strip()
            if not tag_name:
                continue
            cursor.execute("INSERT IGNORE INTO Tags (tag_name) VALUES (%s)", (tag_name,))
            cursor.execute("SELECT tag_id FROM Tags WHERE tag_name=%s", (tag_name,))
            tag_id = cursor.fetchone()[0]
            cursor.execute("INSERT IGNORE INTO ProblemTags VALUES (%s, %s)", (problem_id, tag_id))

        conn.commit()
        return {"problem_id": problem_id, "message": "Problem created"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.put("/problems/{problem_id}")
def update_problem(problem_id: int, data: ProblemUpdate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        fields, values = [], []
        if data.title is not None:
            fields.append("title = %s"); values.append(data.title)
        if data.difficulty is not None:
            fields.append("difficulty = %s"); values.append(data.difficulty)
            pts = {"Easy": 50, "Medium": 100, "Hard": 200}.get(data.difficulty, 50)
            fields.append("points = %s"); values.append(pts)
        if data.description is not None:
            fields.append("description = %s"); values.append(data.description)
        if data.function_signature is not None:
            fields.append("function_signature = %s"); values.append(data.function_signature)

        if fields:
            values.append(problem_id)
            cursor.execute(
                f"UPDATE Problems SET {', '.join(fields)} WHERE problem_id = %s", values
            )

        if data.tags is not None:
            cursor.execute("DELETE FROM ProblemTags WHERE problem_id = %s", (problem_id,))
            for tag_name in data.tags:
                tag_name = tag_name.strip()
                if not tag_name:
                    continue
                cursor.execute("INSERT IGNORE INTO Tags (tag_name) VALUES (%s)", (tag_name,))
                cursor.execute("SELECT tag_id FROM Tags WHERE tag_name=%s", (tag_name,))
                row = cursor.fetchone()
                if row:
                    cursor.execute("INSERT IGNORE INTO ProblemTags VALUES (%s, %s)", (problem_id, row[0]))

        conn.commit()
        return {"message": "Problem updated"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.delete("/problems/{problem_id}")
def delete_problem(problem_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Problems WHERE problem_id = %s", (problem_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Problem not found")
        conn.commit()
        return {"message": "Problem deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─── Test Cases ───────────────────────────────────────────────────────────────
@app.get("/problems/{problem_id}/testcases")
def get_test_cases(problem_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT testcase_id, problem_id, input, expected_output FROM TestCases WHERE problem_id = %s ORDER BY testcase_id",
        (problem_id,)
    )
    return cursor.fetchall()


@app.post("/problems/{problem_id}/testcases")
def add_test_case(problem_id: int, data: TestCaseCreate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO TestCases (problem_id, input, expected_output) VALUES (%s, %s, %s)",
            (problem_id, data.input, data.expected_output)
        )
        conn.commit()
        return {"testcase_id": cursor.lastrowid, "message": "Test case added"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/problems/{problem_id}/testcases/bulk")
def add_test_cases_bulk(problem_id: int, data: TestCaseBulkCreate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        inserted = 0
        for tc in data.test_cases:
            cursor.execute(
                "INSERT INTO TestCases (problem_id, input, expected_output) VALUES (%s, %s, %s)",
                (problem_id, tc.get("input", ""), tc.get("expected_output", ""))
            )
            inserted += 1
        conn.commit()
        return {"inserted": inserted}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.put("/testcases/{testcase_id}")
def update_test_case(testcase_id: int, data: TestCaseUpdate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        fields, values = [], []
        if data.input is not None:
            fields.append("input = %s"); values.append(data.input)
        if data.expected_output is not None:
            fields.append("expected_output = %s"); values.append(data.expected_output)
        if not fields:
            return {"message": "Nothing to update"}
        values.append(testcase_id)
        cursor.execute(
            f"UPDATE TestCases SET {', '.join(fields)} WHERE testcase_id = %s", values
        )
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Test case not found")
        conn.commit()
        return {"message": "Test case updated"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.delete("/testcases/{testcase_id}")
def delete_test_case(testcase_id: int):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM TestCases WHERE testcase_id = %s", (testcase_id,))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Test case not found")
        conn.commit()
        return {"message": "Test case deleted"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─── Contests ─────────────────────────────────────────────────────────────────
@app.get("/contests")
def get_contests():
    """Return all contests (used by admin / create-contest flow)."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Contests ORDER BY start_time DESC")
    return cursor.fetchall()


@app.get("/contests/joined/{user_id}")
def get_joined_contests(user_id: int):
    """Return contests this user has joined, with their problems."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT c.*
        FROM Contests c
        JOIN ContestMembers cm ON c.contest_id = cm.contest_id
        WHERE cm.user_id = %s
        ORDER BY c.start_time DESC
    """, (user_id,))
    contests = cursor.fetchall()

    for c in contests:
        cursor.execute("""
            SELECT p.problem_id, p.title, p.difficulty, p.points
            FROM ContestProblems cp
            JOIN Problems p ON cp.problem_id = p.problem_id
            WHERE cp.contest_id = %s
        """, (c["contest_id"],))
        c["problems"] = cursor.fetchall()

    return contests


@app.get("/contests/{contest_id}")
def get_contest(contest_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Contests WHERE contest_id=%s", (contest_id,))
    contest = cursor.fetchone()
    if not contest:
        raise HTTPException(status_code=404, detail="Contest not found")

    cursor.execute("""
        SELECT p.problem_id, p.title, p.difficulty, p.points
        FROM ContestProblems cp
        JOIN Problems p ON cp.problem_id = p.problem_id
        WHERE cp.contest_id = %s
    """, (contest_id,))
    contest["problems"] = cursor.fetchall()
    return contest


@app.post("/contests")
def create_contest(data: ContestCreate):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        # Generate a unique join code
        for _ in range(10):
            code = _generate_join_code()
            cursor.execute("SELECT 1 FROM Contests WHERE join_code=%s", (code,))
            if not cursor.fetchone():
                break

        cursor.execute(
            "INSERT INTO Contests (title, start_time, end_time, join_code) VALUES (%s, %s, %s, %s)",
            (data.title, data.start_time, data.end_time, code),
        )
        contest_id = cursor.lastrowid

        for pid in data.problem_ids:
            cursor.execute("INSERT IGNORE INTO ContestProblems VALUES (%s, %s)", (contest_id, pid))

        conn.commit()
        return {"contest_id": contest_id, "join_code": code, "message": "Contest created"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/contests/join")
def join_contest(data: ContestJoin):
    """Join a contest via its human-readable join code."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT contest_id, title, join_code FROM Contests WHERE join_code=%s",
        (data.join_code.strip().lower(),)
    )
    contest = cursor.fetchone()
    if not contest:
        raise HTTPException(status_code=404, detail="Invalid join code — no contest found.")

    cursor2 = conn.cursor()
    try:
        cursor2.execute(
            "INSERT IGNORE INTO ContestMembers (contest_id, user_id) VALUES (%s, %s)",
            (contest["contest_id"], data.user_id)
        )
        conn.commit()
        return {
            "contest_id": contest["contest_id"],
            "title": contest["title"],
            "message": f"Joined '{contest['title']}' successfully!"
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


# ─── LeetCode-style Code Execution ───────────────────────────────────────────
def _build_harness(language: str, source_code: str, sig: dict | None, args_json: str, expected: str) -> tuple[str, str]:
    """
    Returns (harness_code, stdin) to pass to Judge0.
    For Python with a function signature: wraps user code with test harness.
    For others (or no signature): passes args_json as stdin.
    """
    if language == "python" and sig:
        harness = _build_python_harness(source_code, sig, args_json, expected)
        return harness, ""   # no stdin needed — args baked into harness
    else:
        # Fallback: raw stdin mode
        return source_code, args_json


@app.post("/run")
async def run_code(data: CodeSubmissionIn):
    """Run code against first 2 sample test cases (no verdict stored)."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    problem = _get_problem_with_sig(cursor, data.problem_id)
    sig = problem["_sig"]

    cursor.execute(
        "SELECT input, expected_output FROM TestCases WHERE problem_id=%s LIMIT 2",
        (data.problem_id,),
    )
    test_cases = cursor.fetchall()

    if not test_cases:
        test_cases = [{"input": "", "expected_output": ""}]

    results = []
    for tc in test_cases:
        harness, stdin = _build_harness(
            data.language, data.source_code, sig,
            tc.get("input", ""), tc.get("expected_output", "")
        )
        result = await judge0_submit(data.language, harness, stdin)
        stdout = b64_decode(result.get("stdout") or "").strip()
        stderr = b64_decode(result.get("stderr") or "")
        compile_output = b64_decode(result.get("compile_output") or "")
        status, exec_time = interpret_judge0_status(result, stdout)

        results.append({
            "input": tc.get("input", ""),
            "expected_output": tc.get("expected_output", ""),
            "actual_output": stdout,
            "status": status,
            "execution_time": exec_time,
            "stderr": stderr or compile_output,
        })

    return {"results": results}


@app.post("/submit_code")
async def submit_code(data: CodeSubmissionIn):
    """Judge against ALL test cases and persist result."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    problem = _get_problem_with_sig(cursor, data.problem_id)
    sig = problem["_sig"]

    cursor.execute(
        "SELECT input, expected_output FROM TestCases WHERE problem_id=%s",
        (data.problem_id,),
    )
    test_cases = cursor.fetchall()

    if not test_cases:
        raise HTTPException(status_code=400, detail="No test cases for this problem")

    all_passed = True
    worst_status = "Accepted"
    total_time = 0.0
    details = []

    for i, tc in enumerate(test_cases):
        harness, stdin = _build_harness(
            data.language, data.source_code, sig,
            tc.get("input", ""), tc.get("expected_output", "")
        )
        result = await judge0_submit(data.language, harness, stdin)
        stdout = b64_decode(result.get("stdout") or "").strip()
        status, exec_time = interpret_judge0_status(result, stdout)
        total_time += exec_time
        details.append({"test_case": i + 1, "status": status, "time": exec_time})

        if status != "Accepted":
            all_passed = False
            worst_status = status
            break  # fail fast

    final_status = "Accepted" if all_passed else worst_status
    avg_time = total_time / len(details)

    # Persist
    cursor2 = conn.cursor()
    try:
        cursor2.execute(
            """INSERT INTO Submissions (user_id, problem_id, contest_id, status, execution_time)
               VALUES (%s, %s, %s, %s, %s)""",
            (data.user_id, data.problem_id, data.contest_id, final_status, avg_time),
        )
        conn.commit()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {
        "status": final_status,
        "execution_time": round(avg_time, 4),
        "test_results": details,
        "message": "All test cases passed!" if all_passed else f"Failed on test {len(details)}: {worst_status}",
    }


# ─── Leaderboard ──────────────────────────────────────────────────────────────
@app.get("/leaderboard/{contest_id}")
def get_leaderboard(contest_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    query = """
        SELECT
            u.username,
            COUNT(DISTINCT s.problem_id) AS problems_solved,
            SUM(p.points)               AS total_score,
            SUM(s.execution_time)       AS total_time
        FROM Submissions s
        JOIN Users u ON s.user_id = u.user_id
        JOIN Problems p ON s.problem_id = p.problem_id
        WHERE s.status = 'Accepted'
          AND s.contest_id = %s
          AND s.submission_id IN (
              SELECT MIN(s2.submission_id)
              FROM Submissions s2
              WHERE s2.contest_id = %s AND s2.status = 'Accepted'
              GROUP BY s2.user_id, s2.problem_id
          )
        GROUP BY u.user_id, u.username
        ORDER BY total_score DESC, total_time ASC
    """
    cursor.execute(query, (contest_id, contest_id))
    rows = cursor.fetchall()
    for i, r in enumerate(rows):
        r["rank"] = i + 1
    return rows


# ─── Submissions ──────────────────────────────────────────────────────────────
@app.get("/submissions/{user_id}")
def get_user_submissions(user_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        """SELECT s.submission_id, p.title, s.status,
                  s.execution_time, s.submission_time, c.title AS contest_title
           FROM Submissions s
           JOIN Problems p ON s.problem_id = p.problem_id
           LEFT JOIN Contests c ON s.contest_id = c.contest_id
           WHERE s.user_id = %s
           ORDER BY s.submission_time DESC""",
        (user_id,),
    )
    return cursor.fetchall()


@app.get("/")
def home():
    return {"message": "Coding Platform API Running"}