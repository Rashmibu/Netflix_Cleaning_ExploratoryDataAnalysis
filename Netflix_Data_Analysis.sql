----------- HANDLING FOREIGN CHARACTERS IN TITLE COLUMN ----------
CREATE TABLE [dbo].[netflix_raw](
	   [show_id] [varchar](10) PRIMARY KEY
      ,[type] [varchar](10) NULL
      ,[title] [nvarchar](200) NULL
      ,[director] [varchar](250) NULL
      ,[cast] [varchar](1000) NULL
      ,[country] [varchar](150) NULL
      ,[date_added] [varchar](20) NULL
      ,[release_year] [int] NULL
      ,[rating] [varchar](10) NULL
      ,[duration] [varchar](12) NULL
      ,[listed_in] [varchar](100) NULL
      ,[description] [varchar](500) NULL)

--------- REMOVE DUPLICATES ----------
select show_id,count(*) as n
from netflix_raw
group by show_id
having count(*)>1

WITH cte AS(
SELECT *,
row_number() OVER(PARTITION BY type,title,director ORDER BY title) as dup
FROM netflix_raw)
SELECT * FROM cte
WHERE dup>1

-- Deleting 3 found duplicates --
DELETE FROM netflix_raw
WHERE show_id in ('s6706','s7346','s1271')
SELECT * FROM netflix_raw--8804 ROWS, 3 DUPLUICATES REMOVED


---------- CREATE NEW TABLE FOR LISTEDIN, DIRECTOR, COUNTRY, CAST ---------
--1) New table: netflix_director --
SELECT show_id, trim(value) as director
into netflix_director
FROM Netflix_raw
CROSS APPLY string_split(director,',')

--2) New table: netflix_country --
SELECT show_id, trim(value) as country
into netflix_country
FROM Netflix_raw
CROSS APPLY string_split(country,',')

--3) New table: netflix_cast --
SELECT show_id, trim(value) as cast
into netflix_cast
FROM Netflix_raw
CROSS APPLY string_split(cast,',')

--4) New table: netflix_genre --
SELECT show_id, trim(value) as genre
into netflix_genre
FROM Netflix_raw
CROSS APPLY string_split(listed_in,',')


---------- POPULATE VALUES FOR NULL: COUNTRY,DURATION ----------
select * from netflix_raw where rating is null
--1) COUNTRY --
INSERT INTO netflix_country
SELECT show_id,netflix.country
FROM netflix_raw nr
inner join(
SELECT director,country FROM netflix_country nc
inner join netflix_director nd 
ON nd.show_id=nc.show_id
GROUP BY director,country) netflix
ON netflix.director=nr.director
WHERE nr.country is null

-- 2) DURATION --
SELECT show_id,type,title,cast(date_added as date) AS date_added ,release_year,rating,
CASE WHEN duration is null THEN rating ELSE duration END AS duration,description 
INTO netflix
FROM netflix_raw


---------- EXPLORATORY DATA ANALYSIS -----------

-- 1) Display No. of movies, TV shows directed by each Director and total count of movies,TVShow --
SELECT Director,count(DISTINCT type) AS Distinct_Genre,
COUNT(DISTINCT CASE WHEN type='Movie' THEN n.show_id end) as No_of_Movies,
COUNT(DISTINCT CASE WHEN type='TV Show' THEN n.show_id end) as No_of_TVShows,
count(type) AS Total_no_movies_TVShows
FROM netflix n
inner join netflix_director nd
ON n.show_id=nd.show_id
GROUP BY director
HAVING count(DISTINCT type)>1
ORDER  BY Distinct_Genre DESC


-- 2) Which country has highest number of comedy movies? --
SELECT TOP 1 count(distinct n.show_id) AS No_of_Comedy_Movies,country
FROM netflix n 
inner join netflix_genre ng ON n.show_id=ng.show_id
inner join netflix_country nc ON nc.show_id=n.show_id
WHERE genre='Comedies' and n.type='Movie'
GROUP BY country
ORDER BY No_of_Comedy_Movies DESC

-- 3) For each year,which director has maximum no. of movies released? --
WITH cte as(
SELECT director,count(n.show_id) as no_of_movies_released, YEAR(date_added) AS Release_year
FROM netflix n
inner join netflix_director nd ON n.show_id=nd.show_id
WHERE TYPE='Movie'
GROUP BY YEAR(date_added),director),
cte2 AS(SELECT *,
row_number() OVER(PARTITION BY Release_year ORDER BY no_of_movies_released DESC,director ) AS rn 
FROM cte)
SELECT director, Release_year,no_of_movies_released FROM cte2
WHERE rn=1

-- 4)	What is the average duration of movies in each genre? --
SELECT genre,avg(CAST(replace(duration,' min','') as int)) as avg_duration_in_mins
FROM netflix n
inner join netflix_genre ng ON n.show_id=ng.show_id
WHERE type='Movie'
GROUP BY genre
ORDER BY Genre


-- 5) Find the list directors who have directed both horror and comedy movies and display number of horror and comedy respectively--
SELECT  director,
COUNT(DISTINCT CASE WHEN genre='Horror Movies' THEN n.show_id end) AS No_of_horror_movies,
COUNT(DISTINCT CASE WHEN genre='Comedies' THEN n.show_id end)AS No_of_Comedies
FROM netflix n
inner join netflix_genre ng ON n.show_id=ng.show_id
inner join netflix_director nd ON nd.show_id=n.show_id
WHERE TYPE='Movie'and genre IN('Horror Movies','Comedies')
GROUP BY director
HAVING count(DISTINCT genre)=2
ORDER BY director







