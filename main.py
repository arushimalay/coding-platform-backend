from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import httpx
import base64
import asyncio
import json
import random
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
    "python": 71,
    "cpp":    54,
    "c":      50,
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
    source_code: str

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
    created_by: Optional[int] = None

class ContestJoin(BaseModel):
    user_id: int
    join_code: str

class ProblemCreate(BaseModel):
    title: str
    difficulty: str
    description: str = ""
    tags: list[str] = []
    harness_template: str = ""
    starter_code: str = ""
    created_by: Optional[int] = None

class ProblemUpdate(BaseModel):
    title: Optional[str] = None
    difficulty: Optional[str] = None
    description: Optional[str] = None
    tags: Optional[list[str]] = None
    harness_template: Optional[str] = None
    starter_code: Optional[str] = None

class TestCaseCreate(BaseModel):
    problem_id: int
    input: str
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


def _build_harness(harness_template: str, source_code: str, args: str, expected: str) -> str:
    """
    Substitute the three placeholders in the problem maker's harness template.
    {{USER_CODE}}  → the user's submitted source code
    {{INPUT}}      → the test case input string
    {{EXPECTED}}   → the expected output string
    """
    return (
        harness_template
        .replace("{{USER_CODE}}", source_code)
        .replace("{{INPUT}}", args)
        .replace("{{EXPECTED}}", expected)
    )


async def judge0_submit(language: str, source_code: str, stdin: str = "", expected_output: str = "") -> dict:
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
    status_id = result.get("status", {}).get("id", 0)
    exec_time = float(result.get("time") or 0)

    if status_id == 6:
        return "Compilation Error", exec_time
    if status_id in (7, 8, 9, 10, 11, 12):
        return "Runtime Error", exec_time
    if status_id == 5:
        return "Time Limit Exceeded", exec_time
    if status_id == 13:
        return "Internal Error", exec_time

    if stdout.strip().startswith("PASS"):
        return "Accepted", exec_time
    if stdout.strip().startswith("FAIL"):
        return "Wrong Answer", exec_time

    return {3: "Accepted", 4: "Wrong Answer"}.get(status_id, "Unknown"), exec_time


def _get_problem(cursor, problem_id: int) -> dict:
    cursor.execute(
        "SELECT problem_id, title, difficulty, points, description, harness_template, starter_code "
        "FROM Problems WHERE problem_id=%s",
        (problem_id,)
    )
    row = cursor.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Problem not found")
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
        SELECT p.problem_id, p.title, p.difficulty, p.points, p.created_by,
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
            "INSERT INTO Problems (title, difficulty, description, harness_template, starter_code, created_by) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (data.title, data.difficulty, data.description,
             data.harness_template or None, data.starter_code or None, data.created_by),
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
        if data.harness_template is not None:
            fields.append("harness_template = %s"); values.append(data.harness_template)
        if data.starter_code is not None:
            fields.append("starter_code = %s"); values.append(data.starter_code)

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
def delete_problem(problem_id: int, user_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT created_by FROM Problems WHERE problem_id = %s", (problem_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Problem not found")
        if row["created_by"] != user_id:
            raise HTTPException(status_code=403, detail="You can only delete problems you created")
        cursor2 = conn.cursor()
        cursor2.execute("DELETE FROM Problems WHERE problem_id = %s", (problem_id,))
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
        "SELECT testcase_id, problem_id, input, expected_output FROM TestCases "
        "WHERE problem_id = %s ORDER BY testcase_id",
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
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Contests ORDER BY start_time DESC")
    return cursor.fetchall()


@app.get("/contests/joined/{user_id}")
def get_joined_contests(user_id: int):
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

        # Auto-join the creator
        if data.created_by:
            cursor.execute(
                "INSERT IGNORE INTO ContestMembers (contest_id, user_id) VALUES (%s, %s)",
                (contest_id, data.created_by)
            )

        conn.commit()
        return {"contest_id": contest_id, "join_code": code, "message": "Contest created"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/contests/join")
def join_contest(data: ContestJoin):
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


# ─── Code Execution ───────────────────────────────────────────────────────────
@app.post("/run")
async def run_code(data: CodeSubmissionIn):
    """Run against first 2 sample test cases (no verdict stored)."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    problem = _get_problem(cursor, data.problem_id)
    harness_template = problem.get("harness_template") or ""

    if not harness_template:
        raise HTTPException(
            status_code=400,
            detail="This problem has no harness configured. Contact the problem setter."
        )

    cursor.execute(
        "SELECT input, expected_output FROM TestCases WHERE problem_id=%s LIMIT 2",
        (data.problem_id,),
    )
    test_cases = cursor.fetchall()
    if not test_cases:
        test_cases = [{"input": "", "expected_output": ""}]

    results = []
    for tc in test_cases:
        harness = _build_harness(
            harness_template,
            data.source_code,
            tc.get("input", ""),
            tc.get("expected_output", ""),
        )
        result = await judge0_submit(data.language, harness)
        stdout = b64_decode(result.get("stdout") or "").strip()
        stderr = b64_decode(result.get("stderr") or "")
        compile_output = b64_decode(result.get("compile_output") or "")
        status, exec_time = interpret_judge0_status(result, stdout)

        results.append({
            "input":           tc.get("input", ""),
            "expected_output": tc.get("expected_output", ""),
            "actual_output":   stdout,
            "status":          status,
            "execution_time":  exec_time,
            "stderr":          stderr or compile_output,
        })

    return {"results": results}


@app.post("/submit_code")
async def submit_code(data: CodeSubmissionIn):
    """Judge against ALL test cases and persist result."""
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    problem = _get_problem(cursor, data.problem_id)
    harness_template = problem.get("harness_template") or ""

    if not harness_template:
        raise HTTPException(
            status_code=400,
            detail="This problem has no harness configured. Contact the problem setter."
        )

    cursor.execute(
        "SELECT input, expected_output FROM TestCases WHERE problem_id=%s",
        (data.problem_id,),
    )
    test_cases = cursor.fetchall()

    if not test_cases:
        raise HTTPException(status_code=400, detail="No test cases for this problem")

    all_passed  = True
    worst_status = "Accepted"
    total_time  = 0.0
    details     = []

    for i, tc in enumerate(test_cases):
        harness = _build_harness(
            harness_template,
            data.source_code,
            tc.get("input", ""),
            tc.get("expected_output", ""),
        )
        result = await judge0_submit(data.language, harness)
        stdout = b64_decode(result.get("stdout") or "").strip()
        status, exec_time = interpret_judge0_status(result, stdout)
        total_time += exec_time
        details.append({"test_case": i + 1, "status": status, "time": exec_time})

        if status != "Accepted":
            all_passed   = False
            worst_status = status
            break  # fail fast

    final_status = "Accepted" if all_passed else worst_status
    avg_time     = total_time / len(details)

    cursor2 = conn.cursor()
    try:
        cursor2.execute(
            "INSERT INTO Submissions (user_id, problem_id, contest_id, status, execution_time) "
            "VALUES (%s, %s, %s, %s, %s)",
            (data.user_id, data.problem_id, data.contest_id, final_status, avg_time),
        )
        conn.commit()
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {
        "status":         final_status,
        "execution_time": round(avg_time, 4),
        "test_results":   details,
        "message":        "All test cases passed!" if all_passed
                          else f"Failed on test {len(details)}: {worst_status}",
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
        JOIN Users u    ON s.user_id    = u.user_id
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
