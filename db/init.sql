--create table
CREATE TABLE books (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    author VARCHAR(255),
    status VARCHAR(255)
);

--populate table
INSERT INTO books (title, author, status)
VALUES ('For the Emperor', 'Sandy Mitchell', 'read'),
('The Hobbit', 'J. R. R. Tolkien', 'read'),
('The Bell Jar', 'Sylvia Plath', 'read'),
('Dracula', 'Bram Stoker', 'reading'),
('The Master and Margarita', 'Mikhail Bulgakov', 'to be read');