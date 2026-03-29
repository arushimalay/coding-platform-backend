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
    problem_id         INT PRIMARY KEY AUTO_INCREMENT,
    title              VARCHAR(255) NOT NULL,
    difficulty         VARCHAR(10) CHECK (difficulty IN ('Easy','Medium','Hard')),
    points             INT,
    description        TEXT,
    -- LeetCode-style function metadata stored as JSON string
    -- e.g. {"name":"twoSum","params":[{"name":"nums","type":"List[int]"},{"name":"target","type":"int"}],"return_type":"List[int]"}
    function_signature TEXT
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
    -- For function-style problems: input stores JSON arg list, e.g. '[[2,7,11,15], 9]'
    -- expected_output stores the return value as string, e.g. '[0, 1]'
    input           TEXT,
    expected_output TEXT,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

CREATE TABLE Contests (
    contest_id INT PRIMARY KEY AUTO_INCREMENT,
    title      VARCHAR(100),
    start_time DATETIME,
    end_time   DATETIME,
    -- Random human-readable join code like "swift-tiger-42"
    join_code  VARCHAR(50) UNIQUE
);

CREATE TABLE ContestProblems (
    contest_id INT,
    problem_id INT,
    PRIMARY KEY (contest_id, problem_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id) ON DELETE CASCADE,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

-- Tracks which users have joined which contests (persisted across sessions)
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

-- Problems now include function_signature JSON
INSERT INTO Problems (title, difficulty, description, function_signature) VALUES
('Two Sum', 'Easy',
 'Given an array of integers nums and an integer target, return the indices of the two numbers such that they add up to target.\n\nYou may assume that each input would have exactly one solution, and you may not use the same element twice.\n\nReturn the answer in any order.',
 '{"name":"twoSum","params":[{"name":"nums","type":"List[int]"},{"name":"target","type":"int"}],"return_type":"List[int]"}'
),
('Binary Search', 'Medium',
 'Given a sorted array of distinct integers and a target value, return the index of the target using binary search. Return -1 if not found.',
 '{"name":"search","params":[{"name":"nums","type":"List[int]"},{"name":"target","type":"int"}],"return_type":"int"}'
),
('Graph Paths', 'Hard',
 'Given an undirected graph with V vertices (0-indexed) and E edges represented as an adjacency list, find the shortest path length from vertex 0 to vertex V-1 using BFS. Return -1 if no path exists.\n\nThe graph is passed as a list of edges, e.g. [[0,1],[1,2]].',
 '{"name":"shortestPath","params":[{"name":"V","type":"int"},{"name":"edges","type":"List[List[int]]"}],"return_type":"int"}'
);

INSERT INTO Tags (tag_name) VALUES
('array'), ('hashmap'), ('binary-search'), ('graph'), ('bfs'), ('two-pointers');

INSERT INTO ProblemTags VALUES (1, 1), (1, 2);
INSERT INTO ProblemTags VALUES (2, 3);
INSERT INTO ProblemTags VALUES (3, 4), (3, 5);

-- Test cases now use JSON-encoded arguments as input
-- Two Sum: input = JSON list of args [nums, target], output = JSON list [i, j]
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(1, '[[2, 7, 11, 15], 9]',  '[0, 1]'),
(1, '[[3, 2, 4], 6]',       '[1, 2]'),
(1, '[[3, 3], 6]',          '[0, 1]');

-- Binary Search: input = [nums, target], output = index
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(2, '[[1, 3, 5, 7, 9], 7]', '3'),
(2, '[[1, 3, 5, 7, 9], 1]', '0'),
(2, '[[1, 3, 5, 7, 9], 6]', '-1');

-- Graph Paths: input = [V, edges], output = shortest path length
INSERT INTO TestCases (problem_id, input, expected_output) VALUES
(3, '[4, [[0,1],[1,2],[2,3],[0,3]]]', '2'),
(3, '[2, [[0,1]]]',                   '1'),
(3, '[3, [[0,1]]]',                   '-1');

-- Contest with a human-readable join code
INSERT INTO Contests (title, start_time, end_time, join_code) VALUES
('Weekly Contest', NOW(), DATE_ADD(NOW(), INTERVAL 2 HOUR), 'swift-tiger-42');

INSERT INTO ContestProblems VALUES (1,1), (1,2), (1,3);

-- Both seed users join the contest
INSERT INTO ContestMembers (contest_id, user_id) VALUES (1, 1), (1, 2);

-- Sample accepted submissions
INSERT INTO Submissions (user_id, problem_id, contest_id, status, execution_time) VALUES
(1, 1, 1, 'Accepted', 0.5),
(1, 2, 1, 'Accepted', 0.7),
(2, 1, 1, 'Accepted', 0.4);