CREATE DATABASE coding_platform;
USE coding_platform;

CREATE TABLE Users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    password VARCHAR(255) NOT NULL
);

CREATE TABLE Problems (
    problem_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    difficulty VARCHAR(10) CHECK (difficulty IN ('Easy','Medium','Hard')),
    points INT
);

CREATE TABLE Tags (
    tag_id INT PRIMARY KEY AUTO_INCREMENT,
    tag_name VARCHAR(50) UNIQUE
);

CREATE TABLE ProblemTags (
    problem_id INT,
    tag_id INT,
    PRIMARY KEY (problem_id, tag_id),
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES Tags(tag_id) ON DELETE CASCADE
);

CREATE TABLE TestCases (
    testcase_id INT PRIMARY KEY AUTO_INCREMENT,
    problem_id INT,
    input TEXT,
    expected_output TEXT,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

CREATE TABLE Contests (
    contest_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100),
    start_time DATETIME,
    end_time DATETIME
);

CREATE TABLE ContestProblems (
    contest_id INT,
    problem_id INT,
    PRIMARY KEY (contest_id, problem_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id) ON DELETE CASCADE,
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id) ON DELETE CASCADE
);

CREATE TABLE Submissions (
    submission_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT,
    problem_id INT,
    contest_id INT,
    status VARCHAR(20),
    execution_time FLOAT,
    submission_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES Users(user_id),
    FOREIGN KEY (problem_id) REFERENCES Problems(problem_id),
    FOREIGN KEY (contest_id) REFERENCES Contests(contest_id)
);

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
        SET NEW.points = 150;
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER check_contest_time
BEFORE INSERT ON Submissions
FOR EACH ROW
BEGIN
    DECLARE endTime DATETIME;
    IF NEW.contest_id IS NOT NULL THEN
        SELECT end_time INTO endTime 
        FROM Contests 
        WHERE contest_id = NEW.contest_id;
        IF NOW() > endTime THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Contest has ended!';
        END IF;
    END IF;
END //
DELIMITER ;

INSERT INTO Users (username, email, password) VALUES 
('Arushi', 'aru@gmail.com', '123'),
('Rahul', 'rahul@gmail.com', '123');

INSERT INTO Problems (title, difficulty) VALUES 
('Two Sum', 'Easy'),
('Binary Search', 'Medium'),
('Graph Paths', 'Hard');

INSERT INTO Contests (title, start_time, end_time) VALUES 
('Weekly Contest', NOW(), DATE_ADD(NOW(), INTERVAL 2 HOUR));

INSERT INTO ContestProblems VALUES (1,1), (1,2), (1,3);

INSERT INTO Submissions (user_id, problem_id, contest_id, status, execution_time) VALUES
(1,1,1,'Accepted',0.5),
(1,2,1,'Accepted',0.7),
(2,1,1,'Accepted',0.4);
