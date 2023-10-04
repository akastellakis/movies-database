-----------------------------------------------------------
-- Author: Antonis Kastellakis
-- Description: This script performs data cleaning and normalization 
-- operations on the 'movies' table. It includes steps to import 
-- data from a CSV file, remove duplicates, alter column types, 
-- clean and split date entries, categorize movies, and create 
-- relationships with genres, directors, and stars. 
------------------------------------------------------------

-- Create table Movies.
CREATE TABLE movies (
	movie_id SERIAL PRIMARY KEY,
	movies VARCHAR(150),
  	year VARCHAR(50),
    genre VARCHAR(50),
    rating NUMERIC (2,1),
	one_line VARCHAR(1000),
	stars VARCHAR(1000),
	votes VARCHAR(20),
   	runtime INTEGER,
	gross VARCHAR(20)
);

-- Import the data from the CSV file to the table.
COPY movies (movies,year,genre,rating,one_line,stars,votes,runtime,gross) 
FROM 'C:\Users\Public\Documents\movies.csv'
DELIMITER ','
CSV HEADER;

-- Delete duplicates that have the same movie title, year, stars and one-line
DELETE FROM movies 
WHERE movie_id IN (WITH del_temp AS
				   (SELECT *, ROW_NUMBER() over (PARTITION BY movies,year,stars,one_line ORDER BY stars) AS duplicates
					FROM movies) SELECT movie_id
				     			 FROM del_temp 
				                 WHERE duplicates>=2
				                 ORDER BY movies);


-- Alter column Votes from varchar to integer.
-- Alter column gross from varchar to numeric  
-- and get rid of the special characters '$','M'.
UPDATE movies 
SET votes = REPLACE(votes,',',''),
	gross = CAST(TRIM('$M' FROM gross) AS NUMERIC)*1000000;
	
ALTER TABLE movies
ALTER COLUMN votes SET DATA TYPE INTEGER USING votes::integer,
ALTER COLUMN gross SET DATA TYPE NUMERIC USING gross::numeric;
	
-- Empty plots that say 'Add a Plot' in one_line, change into NULL
UPDATE movies 
SET one_line = NULL
WHERE movie_id IN (SELECT movie_id
					FROM movies
					WHERE one_line LIKE '%Add a Plot%');
					
-- Break the date entry to a Start_year and End_year columns 
ALTER TABLE movies 
ADD start_year SMALLINT,
ADD end_year SMALLINT;

WITH temp AS(
	SELECT movie_id, 
			year,
			TRIM('L Video Game I TV Special Video X ) () TV Movie TV short' FROM split_part(year,'–',1)) AS start_year,
			TRIM(' )' FROM split_part(year,'–',2)) AS end_year
	FROM movies
), temp2 AS (
	SELECT movie_id, 
		CAST(NULLIF(start_year,'') AS SMALLINT) AS start_year,
		CAST(NULLIF(end_year,'') AS SMALLINT) AS end_year
	FROM temp
	ORDER BY movie_id
)
UPDATE movies 
SET start_year = temp2.start_year,
	end_year = temp2.end_year
	FROM temp2 WHERE movies.movie_id = temp2.movie_id;
	
-- Create a new column that would specify the category of the movie
ALTER TABLE movies 
ADD category VARCHAR(15);

UPDATE movies 
SET category = (CASE
			  	WHEN year LIKE '%TV Short%' THEN 'TV Short'
			  	WHEN year LIKE '%TV Special%' THEN 'TV Special'
			  	WHEN year LIKE '%TV Movie%' THEN 'TV Movie'
			  	WHEN year LIKE '%Video Game%' THEN 'Video Game'
			  	WHEN year LIKE '%Video%' THEN 'Video'
			  	ELSE NULL
			  END);

-- Create a new column that would contain the latin number/version of the movie
ALTER TABLE movies 
ADD latin_num VARCHAR(10);

UPDATE movies 
SET latin_num = (CASE 
			   		WHEN TRIM('– 0123456789( )) ('FROM split_part(REPLACE(year,' ',''),')(',1)) 
			  			IN ('TVShort','TVSpecial','TVMovie','VideoGame','Video') THEN NULL
			   		WHEN TRIM('– 0123456789( )) ('FROM split_part(REPLACE(year,' ',''),')(',1))= '' THEN NULL
			   		ELSE TRIM('– 0123456789( )) ('FROM split_part(REPLACE(year,' ',''),')(',1))
			  	 END);

-------------------------------------------------
-- 	End of data cleaning. Start of normalization
-------------------------------------------------

-- Create a table with all the distict genres
SELECT DISTINCT TRIM('' FROM UNNEST(string_to_array(REPLACE(REPLACE(genre,E'\n',''),' ',''),',')))  AS genre_category
INTO genre
FROM movies
ORDER BY genre_category;

ALTER TABLE genre
ADD COLUMN genre_id SERIAL PRIMARY KEY,
ALTER COLUMN genre_category SET DATA TYPE VARCHAR(20);

-- Create a relation that connects each genre with one or more movies
WITH genre_temp AS(
	SELECT movie_id, 
	CAST(TRIM('' FROM UNNEST(string_to_array(REPLACE(REPLACE(genre,E'\n',''),' ',''),','))) AS VARCHAR(20))  AS genre_category
	FROM movies
	ORDER BY movie_id
)
SELECT movie_id,genre_id
INTO genre_in_movie
FROM genre NATURAL JOIN genre_temp
ORDER BY movie_id;

-- Add forgein and primary key constraints to the relation genre_in_movie
ALTER TABLE genre_in_movie
ADD CONSTRAINT fk_genre_genre_in_movie FOREIGN KEY (genre_id) REFERENCES genre(genre_id),
ADD CONSTRAINT fk_movie_genre_in_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
ADD CONSTRAINT PK_genre_in_movie PRIMARY KEY(movie_id,genre_id);

-- Create an entity table with all the directors
WITH direc_temp AS(
	SELECT movie_id, stars, split_part(split_part(REPLACE(stars,'|',''),'Star',1),':',2) AS directors
	FROM movies
	ORDER BY movie_id
), direc_temp2 AS(
	SELECT movie_id, 
	CAST(RTRIM(LTRIM(UNNEST(string_to_array(REPLACE(directors,E'\n',''),',')))) AS VARCHAR(50))  AS director
	FROM direc_temp
	ORDER BY director 
)
SELECT DISTINCT director
INTO director
FROM direc_temp2 
ORDER BY director;

ALTER TABLE director
ADD COLUMN director_id SERIAL PRIMARY KEY;

-- Create a relation that connects each director with one or more movies
WITH direc_temp AS(
	SELECT movie_id, stars, split_part(split_part(REPLACE(stars,'|',''),'Star',1),':',2) AS directors
	FROM movies
	ORDER BY movie_id
), direc_temp2 AS(
	SELECT movie_id, 
	CAST(RTRIM(LTRIM(UNNEST(string_to_array(REPLACE(directors,E'\n',''),',')))) AS VARCHAR(50))  AS director
	FROM direc_temp
	ORDER BY director 
)
SELECT DISTINCT movie_id,director_id,director
INTO directs_in_movie
FROM director NATURAL JOIN direc_temp2
ORDER BY movie_id;

-- Add forgein and primary key constraints to the relation directs_in_movie
ALTER TABLE directs_in_movie
ADD CONSTRAINT fk_directs_directs_in_movie FOREIGN KEY (director_id) REFERENCES director(director_id),
ADD CONSTRAINT fk_movie_directs_in_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
ADD CONSTRAINT PK_directs_in_movie PRIMARY KEY(movie_id,director_id);

-- Create an entity table with all the Stars
WITH stars_temp AS(
	SELECT movie_id, stars,
	split_part((CASE
		 			WHEN stars LIKE '%Star:%' THEN REPLACE(stars,'Star:','Stars:')
		 			ELSE stars
	   			END), 'Stars:',2) AS movie_stars
	FROM movies
	ORDER BY movie_id
), stars_temp2 AS(
	SELECT movie_id, stars,
	CAST(RTRIM(LTRIM(UNNEST(string_to_array(REPLACE(movie_stars,E'\n',''),',')))) AS VARCHAR(50))  AS movie_star
	FROM stars_temp
	ORDER BY movie_star 
)
SELECT DISTINCT movie_star AS star
INTO stars
FROM stars_temp2 
ORDER BY star;

ALTER TABLE stars
ADD COLUMN star_id SERIAL PRIMARY KEY;

-- Create a relation that connects each movie star with one or more movies
WITH stars_temp AS(
	SELECT movie_id, stars,
	split_part((CASE
		 			WHEN stars LIKE '%Star:%' THEN REPLACE(stars,'Star:','Stars:')
		 			ELSE stars
	   			END), 'Stars:',2) AS movie_stars
	FROM movies
	ORDER BY movie_id
), stars_temp2 AS(
	SELECT movie_id, stars,
	CAST(RTRIM(LTRIM(UNNEST(string_to_array(REPLACE(movie_stars,E'\n',''),',')))) AS VARCHAR(50))  AS movie_star
	FROM stars_temp
	ORDER BY movie_star 
)
SELECT DISTINCT movie_id,star_id
INTO stars_in_movie
FROM stars, stars_temp2
WHERE stars.star = stars_temp2.movie_star
ORDER BY movie_id;

-- Add forgein and primary key constraints to the relation stars_in_movie
ALTER TABLE stars_in_movie
ADD CONSTRAINT fk_star_stars_in_movie FOREIGN KEY (star_id) REFERENCES stars(star_id),
ADD CONSTRAINT fk_movie_stars_in_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
ADD CONSTRAINT PK_stars_in_movie PRIMARY KEY(movie_id,star_id);

-----------------------------------------------------------------------------
-- Some final alterations to the initial table movies.
-----------------------------------------------------------------------------

ALTER TABLE movies
	RENAME COLUMN movies to movie_title;

ALTER TABLE movies
    DROP COLUMN year, 
	DROP COLUMN genre, 
	DROP COLUMN stars;