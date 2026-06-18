from fastapi import FastAPI

app = FastAPI()

# @app.get("/") #handles GET requests

# def read_root():
#     return {"message": "Hello world!"}

@app.post("/greet")

def greet_user(name: str):
    return {"message": "Hello, " + name + "!"}