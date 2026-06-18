from fastapi import FastAPI
import psycopg

app = FastAPI()

#check app status
@app.get("/health")
def get_health():
    return {"status": "ok"} #check if the app is responding

#print the db
@app.get("/books")
def get_books():
    conn = psycopg.connect(
        host="db",
        dbname="booktracker_db",
        user="admin",
        password="password"
    )
    cur = conn.cursor()
    cur.execute(
        "SELECT * FROM books;"
    )
    books = cur.fetchall()
    cur.close()
    conn.close()
    return {"books": books}