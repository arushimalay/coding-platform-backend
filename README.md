# Coding Platform Backend

## Description
This project is a backend system for a coding platform built using FastAPI and MySQL.

## Features
- Manage users, problems, contests
- Submit solutions
- Generate leaderboard

## How to Run

1. Install dependencies:
pip install -r requirements.txt

2. Start server:
uvicorn main:app --reload

3. Open in browser:
http://127.0.0.1:8000/docs

## API Endpoints
- GET /problems
- GET /contests
- GET /leaderboard/{contest_id}
- POST /submit

## Database
Run schema.sql in MySQL Workbench to create database.

## Tech Stack
- FastAPI
- MySQL
- Python