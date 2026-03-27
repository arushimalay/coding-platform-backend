from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from database import get_connection

app = FastAPI(title="Coding Platform API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class SubmissionIn(BaseModel):
    user_id: int
    problem_id: int
    contest_id: int | None = None
    status: str
    execution_time: float

@app.get("/")
def home():
    return {"message": "Coding Platform API Running"}

@app.get("/problems")
def get_problems():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Problems")
    return cursor.fetchall()

@app.get("/contests")
def get_contests():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM Contests")
    return cursor.fetchall()

@app.get("/leaderboard/{contest_id}")
def get_leaderboard(contest_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    query = """
        SELECT 
            u.username,
            SUM(p.points) AS total_score,
            SUM(s.execution_time) AS total_time
        FROM Submissions s
        JOIN Users u ON s.user_id = u.user_id
        JOIN Problems p ON s.problem_id = p.problem_id
        WHERE s.status = 'Accepted'
        AND s.contest_id = %s
        GROUP BY u.user_id, u.username
        ORDER BY total_score DESC, total_time ASC
    """
    cursor.execute(query, (contest_id,))
    return cursor.fetchall()

@app.post("/submit")
def submit_solution(data: SubmissionIn):
    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """INSERT INTO Submissions 
               (user_id, problem_id, contest_id, status, execution_time)
               VALUES (%s, %s, %s, %s, %s)""",
            (data.user_id, data.problem_id, data.contest_id,
             data.status, data.execution_time)
        )
        conn.commit()
        return {"message": "Submission successful"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/submissions/{user_id}")
def get_user_submissions(user_id: int):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        """SELECT s.submission_id, p.title, s.status, 
                  s.execution_time, s.submission_time
           FROM Submissions s
           JOIN Problems p ON s.problem_id = p.problem_id
           WHERE s.user_id = %s
           ORDER BY s.submission_time DESC""",
        (user_id,)
    )
    return cursor.fetchall()
