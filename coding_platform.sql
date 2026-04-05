CREATE DATABASE IF NOT EXISTS coding_platform;
USE coding_platform;

-- ─── Tables ───────────────────────────────────────────────────────────────────

CREATE TABLE Users (
    user_id  INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50)  NOT NULL,
    email    VARCHAR(100) UNIQUE,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE Problems (
    problem_id       INT PRIMARY KEY AUTO_INCREMENT,
    title            VARCHAR(255) NOT NULL,
    difficulty       VARCHAR(10) CHECK (difficulty IN ('Easy','Medium','Hard')),
    points           INT,
    description      TEXT,
    harness_template TEXT,
    starter_code     TEXT
);

CREATE TABLE Tags (
    tag_id   INT PRIMARY KEY AUTO_INCREMENT,
    tag_name VARCHAR(50) UNIQUE
);

CREATE TABLE ProblemTags (
    problem_id INT,
    tag_id     INT,
    PRIMARY KEY (problem_id, tag_id),
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)     REFERENCES Tags(tag_id)         ON DELETE CASCADE
);

CREATE TABLE TestCases (
    testcase_id     INT PRIMARY KEY AUTO_INCREMENT,
    problem_id      INT,
    input           TEXT,
    expected_output TEXT,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

CREATE TABLE Contests (
    contest_id INT PRIMARY KEY AUTO_INCREMENT,
    title      VARCHAR(100),
    start_time DATETIME,
    end_time   DATETIME,
    join_code  VARCHAR(50) UNIQUE
);

CREATE TABLE ContestProblems (
    contest_id INT,
    problem_id INT,
    PRIMARY KEY (contest_id, problem_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id) ON DELETE CASCADE,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

CREATE TABLE ContestMembers (
    contest_id INT,
    user_id    INT,
    joined_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (contest_id, user_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES Users(user_id)       ON DELETE CASCADE
);

CREATE TABLE Submissions (
    submission_id   INT PRIMARY KEY AUTO_INCREMENT,
    user_id         INT,
    problem_id      INT,
    contest_id      INT,
    status          VARCHAR(20) CHECK (status IN ('Accepted','Wrong Answer','Time Limit Exceeded','Compilation Error','Runtime Error','Internal Error','Unknown')),
    execution_time  FLOAT,
    submission_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)    REFERENCES Users(user_id),
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id)
);

-- ─── Triggers ─────────────────────────────────────────────────────────────────

DELIMITER //

CREATE TRIGGER set_problem_points
BEFORE INSERT ON Problems
FOR EACH ROW
BEGIN
    IF NEW.difficulty = 'Easy' THEN
        SET NEW.points = 50;
    ELSEIF NEW.difficulty = 'Medium' THEN
        SET NEW.points = 100;
    ELSEIF NEW.difficulty = 'Hard' THEN
        SET NEW.points = 200;
    END IF;
END //

CREATE TRIGGER check_contest_time
BEFORE INSERT ON Submissions
FOR EACH ROW
BEGIN
    DECLARE startTime DATETIME;
    DECLARE endTime DATETIME;
    IF NEW.contest_id IS NOT NULL THEN
        SELECT start_time, end_time INTO startTime, endTime
        FROM Contests
        WHERE contest_id = NEW.contest_id;
        IF NOW() < startTime THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Contest has not started yet!';
        END IF;
        IF NOW() > endTime THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Contest has ended!';
        END IF;
    END IF;
END //

DELIMITER ;

-- ─── Seed Data ────────────────────────────────────────────────────────────────

INSERT INTO Users (username, email, password) VALUES
('Arushi', 'aru@gmail.com',   '123'),
('Rahul',  'rahul@gmail.com', '123');

-- ── Two Sum ───────────────────────────────────────────────────────────────────
INSERT INTO Problems (title, difficulty, description, harness_template, starter_code) VALUES
('Two Sum', 'Easy',
'Given an array of integers nums and an integer target, return the indices of the two numbers such that they add up to target.

You may assume that each input would have exactly one solution, and you may not use the same element twice.

Return the answer in any order.',
'import json

{{USER_CODE}}

def _run_test():
    args = json.loads(\'{{INPUT}}\')
    expected = json.loads(\'{{EXPECTED}}\')
    nums, target = args[0], args[1]
    result = Solution().twoSum(nums, target)
    if sorted(result) == sorted(expected):
        print("PASS")
    else:
        print("FAIL")
        print("Expected:", expected)
        print("Got:     ", result)

_run_test()',
'from typing import List

class Solution:
    def twoSum(self, nums: List[int], target: int) -> List[int]:
        # Write your solution here
        pass'
);

-- ── Binary Search ─────────────────────────────────────────────────────────────
INSERT INTO Problems (title, difficulty, description, harness_template, starter_code) VALUES
('Binary Search', 'Medium',
'Given a sorted array of distinct integers and a target value, return the index of the target using binary search. Return -1 if not found.',
'import json

{{USER_CODE}}

def _run_test():
    args = json.loads(\'{{INPUT}}\')
    expected = json.loads(\'{{EXPECTED}}\')
    nums, target = args[0], args[1]
    result = Solution().search(nums, target)
    if str(result) == str(expected):
        print("PASS")
    else:
        print("FAIL")
        print("Expected:", expected)
        print("Got:     ", result)

_run_test()',
'from typing import List

class Solution:
    def search(self, nums: List[int], target: int) -> int:
        # Write your solution here
        pass'
);

-- ── Graph Paths ───────────────────────────────────────────────────────────────
INSERT INTO Problems (title, difficulty, description, harness_template, starter_code) VALUES
('Graph Paths', 'Hard',
'Given an undirected graph with V vertices (0-indexed) and E edges represented as a list of edges, find the shortest path length from vertex 0 to vertex V-1 using BFS. Return -1 if no path exists.

The input is passed as [V, edges], e.g. [4, [[0,1],[1,2],[2,3]]].',
'import json
from collections import deque

{{USER_CODE}}

def _run_test():
    args = json.loads(\'{{INPUT}}\')
    expected = json.loads(\'{{EXPECTED}}\')
    V, edges = args[0], args[1]
    result = Solution().shortestPath(V, edges)
    if str(result) == str(expected):
        print("PASS")
    else:
        print("FAIL")
        print("Expected:", expected)
        print("Got:     ", result)

_run_test()',
'from typing import List
from collections import deque

class Solution:
    def shortestPath(self, V: int, edges: List[List[int]]) -> int:
        # Write your solution here
        pass'
);

-- ── Reverse String ────────────────────────────────────────────────────────────
INSERT INTO Problems (title, difficulty, description, harness_template, starter_code) VALUES
('Reverse String', 'Easy',
'Given a string s, return the string reversed.

Example: "hello" -> "olleh"',
'import json

{{USER_CODE}}

def _run_test():
    s = json.loads(\'{{INPUT}}\')
    expected = json.loads(\'{{EXPECTED}}\')
    result = Solution().reverseString(s)
    if str(result) == str(expected):
        print("PASS")
    else:
        print("FAIL")
        print("Expected:", expected)
        print("Got:     ", result)

_run_test()',
'class Solution:
    def reverseString(self, s: str) -> str:
        # Write your solution here
        pass'
);

-- ── FizzBuzz ──────────────────────────────────────────────────────────────────
INSERT INTO Problems (title, difficulty, description, harness_template, starter_code) VALUES
('FizzBuzz', 'Easy',
'Given an integer n, return a list of strings for numbers 1 to n where:
- "FizzBuzz" if divisible by both 3 and 5
- "Fizz" if divisible by 3
- "Buzz" if divisible by 5
- The number as a string otherwise.',
'import json

{{USER_CODE}}

def _run_test():
    n = json.loads(\'{{INPUT}}\')
    expected = json.loads(\'{{EXPECTED}}\')
    result = Solution().fizzBuzz(n)
    if result == expected:
        print("PASS")
    else:
        print("FAIL")
        print("Expected:", expected)
        print("Got:     ", result)

_run_test()',
'from typing import List

class Solution:
    def fizzBuzz(self, n: int) -> List[str]:
        # Write your solution here
        pass'
);

-- ─── Tags ─────────────────────────────────────────────────────────────────────
INSERT INTO Tags (tag_name) VALUES
('array'), ('hashmap'), ('binary-search'), ('graph'), ('bfs'), ('two-pointers'),
('string'), ('math');

-- Two Sum: array, hashmap
INSERT INTO ProblemTags VALUES (1, 1), (1, 2);
-- Binary Search: binary-search, array
INSERT INTO ProblemTags VALUES (2, 3), (2, 1);
-- Graph Paths: graph, bfs
INSERT INTO ProblemTags VALUES (3, 4), (3, 5);
-- Reverse String: string
INSERT INTO ProblemTags VALUES (4, 7);
-- FizzBuzz: math
INSERT INTO ProblemTags VALUES (5, 8);

-- ─── Test Cases ───────────────────────────────────────────────────────────────

-- Two Sum
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(1, '[[2, 7, 11, 15], 9]',  '[0, 1]'),
(1, '[[3, 2, 4], 6]',       '[1, 2]'),
(1, '[[3, 3], 6]',          '[0, 1]');

-- Binary Search
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(2, '[[1, 3, 5, 7, 9], 7]', '3'),
(2, '[[1, 3, 5, 7, 9], 1]', '0'),
(2, '[[1, 3, 5, 7, 9], 6]', '-1');

-- Graph Paths
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(3, '[4, [[0,1],[1,2],[2,3],[0,3]]]', '2'),
(3, '[2, [[0,1]]]',                   '1'),
(3, '[3, [[0,1]]]',                   '-1');

-- Reverse String
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(4, '"hello"',   '"olleh"'),
(4, '"abcdef"',  '"fedcba"'),
(4, '"racecar"', '"racecar"');

-- FizzBuzz
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(5, '5',  '["1", "2", "Fizz", "4", "Buzz"]'),
(5, '15', '["1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz", "11", "Fizz", "13", "14", "FizzBuzz"]'),
(5, '3',  '["1", "2", "Fizz"]');

-- ─── Contest ──────────────────────────────────────────────────────────────────
INSERT INTO Contests (title, start_time, end_time, join_code) VALUES
('Weekly Contest', NOW(), DATE_ADD(NOW(), INTERVAL 2 HOUR), 'swift-tiger-42');

INSERT INTO ContestProblems VALUES (1,1), (1,2), (1,3);

INSERT INTO ContestMembers (contest_id, user_id) VALUES (1, 1), (1, 2);

ALTER TABLE Problems
  ADD COLUMN created_by INT NULL,
  ADD FOREIGN KEY (created_by) REFERENCES Users(user_id) ON DELETE SET NULL;
