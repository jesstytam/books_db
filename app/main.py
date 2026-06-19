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
        host="booksdbpg-server4.postgres.database.azure.com",
        dbname="booktracker_db",
        user="bookadmin",
        password="Password123!",
        sslmode="require"
    )

    cur = conn.cursor()
    cur.execute("SELECT id, title, author, status FROM books;")
    rows = cur.fetchall()

    books = [
        {
            "id": row[0],
            "title": row[1],
            "author": row[2],
            "status": row[3],
        }
        for row in rows
    ]

    cur.close()
    conn.close()

    return {"books": books}