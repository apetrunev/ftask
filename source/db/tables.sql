DROP TABLE IF EXISTS articles;
DROP TABLE IF EXISTS magazines;
DROP TABLE IF EXISTS article_types;
DROP TABLE IF EXISTS author;

CREATE TABLE magazines (
  id serial PRIMARY KEY,
  name varchar(150) NOT NULL
);

CREATE TABLE article_types (
  id serial PRIMARY KEY,
  name varchar(150) NOT NULL
);

CREATE TABLE author (
  id serial PRIMARY KEY,
  name varchar(150) NOT NULL
);

CREATE TABLE articles (
  id serial PRIMARY KEY,
  magazine_id INT,
  article_types_id INT,
  author_id INT,

  CONSTRAINT fk_magazine
    FOREIGN KEY(magazine_id)
      REFERENCES magazines(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE,

  CONSTRAINT fk_article_types
    FOREIGN KEY(article_types_id)
      REFERENCES article_types(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE,

  CONSTRAINT fk_author
    FOREIGN KEY(author_id)
      REFERENCES author(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

\copy author FROM 'author.csv';
\copy article_types FROM 'article_types.csv';
\copy magazines FROM 'magazines.csv';
\copy articles FROM 'articles.csv';
