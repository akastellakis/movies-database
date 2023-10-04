# Movies Database Cleaning and Normalization

This repository contains an SQL script for cleaning, transforming, and normalizing a movies database. The script is designed to enhance data accuracy and integrity by handling tasks such as data deduplication, data type conversion, splitting columns, and creating relationships between entities.

## Usage

1. **Clone the Repository:**

   - git clone https://github.com/your-username/movies-database-cleaning-normalization.git
         
2. **Place the CSV File:**
   - Save your *movies.csv* file in the same directory as your SQL script or in a location accessible by your PostgreSQL database server.
     
3. **Update SQL Script:**
   - Modify the COPY command in movies_database_cleaning_and_normalization.sql to specify the correct path to the movies.csv file.

4. **Run the SQL Script:**
   - Ensure you have access to the PostgreSQL database where you want to apply these changes.
   - Run the movies_database_cleaning_and_normalization.sql script in your PostgreSQL environment to clean and normalize your movies database.

5. **Review the ER-Schema:**
   - An Entity-Relationship (ER) schema is provided in the repository. Check the *er_schema.png* file to understand the database structure and relationships visually.
  
## Database Schema
The cleaned and normalized database includes the following tables and relationships:

- **movies**: Contains cleaned movie data.

- **genre**: Represents distinct movie genres.

- **genre_in_movie**: Connects movies with their corresponding genres.

- **director**: Represents movie directors.

- **directs_in_movie**: Connects movies with their directors.

- **stars**: Represents movie stars.

- **stars_in_movie**: Connects movies with their stars.
